import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class MetricaScreen extends StatefulWidget {
  final String lojaId;

  const MetricaScreen({super.key, required this.lojaId});

  @override
  State<MetricaScreen> createState() => _MetricaScreenState();
}

class _MetricaScreenState extends State<MetricaScreen> {
  final _firestore = FirebaseFirestore.instance;

  // Variáveis para armazenar o agrupamento do gráfico por hora sô!
  Map<int, int> _acessosPorHora = {};
  Map<int, int> _pedidosPorHora = {};
  bool _carregandoGrafico = true;

  @override
  void initState() {
    super.initState();
    _escutarHistoricoGrafico();
  }

  /// 📊 Busca o histórico de HOJE e agrupa por hora para desenhar as linhas do gráfico
  void _escutarHistoricoGrafico() {
    DateTime agora = DateTime.now();
    final inicioDoDia = DateTime(agora.year, agora.month, agora.day, 0, 0, 0);

    _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('historico_metricas').where('criado_em', isGreaterThanOrEqualTo: inicioDoDia).snapshots().listen((snapshot) {
      Map<int, int> temporarioAcessos = {8: 0, 10: 0, 12: 0, 14: 0, 16: 0, 18: 0};
      Map<int, int> temporarioPedidos = {8: 0, 10: 0, 12: 0, 14: 0, 16: 0, 18: 0};

      for (var doc in snapshot.docs) {
        final dados = doc.data();
        final Timestamp? timestamp = dados['criado_em'] as Timestamp?;
        if (timestamp == null) continue;

        final DateTime dataHora = timestamp.toDate();
        final int hora = dataHora.hour;
        final String tipo = dados['tipo'] ?? '';

        // Descobre em qual bloco de hora do gráfico o evento se encaixa melhor sô
        int horaChave = 8;
        if (hora >= 18) {
          horaChave = 18;
        } else if (hora >= 16) {
          horaChave = 16;
        } else if (hora >= 14) {
          horaChave = 14;
        } else if (hora >= 12) {
          horaChave = 12;
        } else if (hora >= 10) {
          horaChave = 10;
        } else {
          horaChave = 8;
        }

        if (tipo == 'acesso_cardapio' || tipo == 'leitura_qrcode') {
          temporarioAcessos[horaChave] = (temporarioAcessos[horaChave] ?? 0) + 1;
        } else if (tipo == 'pedido_whatsapp') {
          temporarioPedidos[horaChave] = (temporarioPedidos[horaChave] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _acessosPorHora = temporarioAcessos;
          _pedidosPorHora = temporarioPedidos;
          _carregandoGrafico = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 950;

    DateTime agora = DateTime.now();
    final inicioDoDia = agora.subtract(const Duration(hours: 24));

    return Scaffold(
      backgroundColor: const Color(0xFF13131A),
      body: StreamBuilder<DocumentSnapshot>(
        // 📡 Stream 1: Puxa os dados em tempo real do Estabelecimento (Acessos e QR Code)
        stream: _firestore.collection('estabelecimentos').doc(widget.lojaId).snapshots(),
        builder: (context, snapshotLoja) {
          if (snapshotLoja.hasError) {
            print(snapshotLoja.error);
            return Center(child: Text('Erro ao carregar as métricas, tente mais tarde!: ${snapshotLoja.error}'));
          }
          if (!snapshotLoja.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
          }

          final dadosLoja = snapshotLoja.data!.data() as Map<String, dynamic>? ?? {};
          final int acessosCardapio = dadosLoja['total_acessos_cardapio'] ?? 0;
          final int leiturasQrCode = dadosLoja['total_leituras_qrcode'] ?? 0;

          return StreamBuilder<QuerySnapshot>(
            // 📡 Stream 2: Puxa os pedidos da loja gerados NO DIA DE HOJE
            stream: _firestore.collection('pedidos').where('estabelecimento_id', isEqualTo: widget.lojaId).where('criado_em', isGreaterThanOrEqualTo: inicioDoDia).snapshots(),
            builder: (context, snapshotPedidos) {
              if (snapshotPedidos.hasError) {
                print(snapshotPedidos.error);
                return Center(child: Text('Erro ao carregar as métricas, tente mais tarde!: ${snapshotPedidos.error}'));
              }
              final int totalPedidosHoje = snapshotPedidos.hasData ? snapshotPedidos.data!.docs.length : 0;

              // Calcula a Conversão da Mesa baseado nas leituras do QR Code físico sô!
              final double taxaConversao = leiturasQrCode > 0 ? (totalPedidosHoje / leiturasQrCode) * 100 : 0.0;

              // Calcula o total de itens pedidos somando o tamanho do carrinho de cada pedido de hoje
              int totalItensSolicitados = 0;
              if (snapshotPedidos.hasData) {
                for (var doc in snapshotPedidos.data!.docs) {
                  final dadosPedido = doc.data() as Map<String, dynamic>? ?? {};
                  final List itens = dadosPedido['itens'] ?? [];
                  totalItensSolicitados += itens.length;
                }
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(ehCelular ? 16.0 : 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Métricas de Operação e Engajamento ⚡',
                      style: GoogleFonts.poppins(fontSize: ehCelular ? 20 : 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acompanhe o volume de acessos e a eficiência dos seus pedidos na feira.',
                      style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: ehCelular ? 13 : 14),
                    ),
                    SizedBox(height: ehCelular ? 24 : 40),

                    // 🎛️ Grid Responsivo de Cards Reais do Firebase sô!
                    ehCelular
                        ? Column(
                            children: _construirCardsOperacionais(
                              acessosCardapio,
                              totalPedidosHoje,
                              taxaConversao,
                              totalItensSolicitados,
                            ).map((card) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: card)).toList(),
                          )
                        : Row(
                            children: _construirCardsOperacionais(acessosCardapio, totalPedidosHoje, taxaConversao, totalItensSolicitados)
                                .map(
                                  (card) => Expanded(
                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: card),
                                  ),
                                )
                                .toList(),
                          ),

                    SizedBox(height: ehCelular ? 24 : 40),

                    // 📈 Bloco do Gráfico de Fluxo Horário Dinâmico
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fluxo de Pedidos vs. Acessos (Por Hora)',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text('Monitore os horários de maior pico de atividade nas mesas.', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
                          const SizedBox(height: 40),

                          SizedBox(
                            height: 320,
                            child: _carregandoGrafico ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))) : _construirGraficoFluxoReal(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _construirCardsOperacionais(int acessos, int pedidos, double conversao, int itens) {
    return [
      _cardMetricaItem(titulo: 'Acessos ao Cardápio', valor: '$acessos', icone: Icons.qr_code_scanner_rounded, corIcone: const Color(0xFF29B6F6)),
      _cardMetricaItem(titulo: 'Pedidos Enviados', valor: '$pedidos', icone: Icons.local_mall_rounded, corIcone: const Color(0xFFE65100)),
      _cardMetricaItem(titulo: 'Conversão de Mesas', valor: '${conversao.toStringAsFixed(1)}%', icone: Icons.bolt_rounded, corIcone: Colors.amber),
      _cardMetricaItem(titulo: 'Produtos Solicitados', valor: '$itens', icone: Icons.restaurant_menu_rounded, corIcone: Colors.purpleAccent),
    ];
  }

  Widget _cardMetricaItem({required String titulo, required String valor, required IconData icone, required Color corIcone}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  valor,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: corIcone.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icone, color: corIcone, size: 28),
          ),
        ],
      ),
    );
  }

  /// 📊 Desenha o gráfico alimentado diretamente com os dados agrupados do Firestore sô!
  Widget _construirGraficoFluxoReal() {
    // Procura qual o maior valor de picos para ajustar o teto (maxY) dinamicamente e o gráfico não amassar
    double maiorValor = 10;
    _acessosPorHora.values.forEach((v) {
      if (v > maiorValor) maiorValor = v.toDouble();
    });
    _pedidosPorHora.values.forEach((v) {
      if (v > maiorValor) maiorValor = v.toDouble();
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[800]!, strokeWidth: 1)),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('${value.toInt().toString().padLeft(2, '0')}h', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 8,
        maxX: 18,
        minY: 0,
        maxY: maiorValor + 5, // Dá uma folguinha de segurança no topo do gráfico sô
        lineBarsData: [
          // 🟠 Linha Laranja: Pedidos Enviados por Hora
          LineChartBarData(
            spots: [
              FlSpot(8, _pedidosPorHora[8]!.toDouble()),
              FlSpot(10, _pedidosPorHora[10]!.toDouble()),
              FlSpot(12, _pedidosPorHora[12]!.toDouble()),
              FlSpot(14, _pedidosPorHora[14]!.toDouble()),
              FlSpot(16, _pedidosPorHora[16]!.toDouble()),
              FlSpot(18, _pedidosPorHora[18]!.toDouble()),
            ],
            isCurved: true,
            color: const Color(0xFFE65100),
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xFFE65100).withOpacity(0.1)),
          ),

          // 🔵 Linha Azul Tracejada: Acessos Gerais por Hora
          LineChartBarData(
            spots: [
              FlSpot(8, _acessosPorHora[8]!.toDouble()),
              FlSpot(10, _acessosPorHora[10]!.toDouble()),
              FlSpot(12, _acessosPorHora[12]!.toDouble()),
              FlSpot(14, _acessosPorHora[14]!.toDouble()),
              FlSpot(16, _acessosPorHora[16]!.toDouble()),
              FlSpot(18, _acessosPorHora[18]!.toDouble()),
            ],
            isCurved: true,
            color: const Color(0xFF29B6F6),
            barWidth: 3,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
