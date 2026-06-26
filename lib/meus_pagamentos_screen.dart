import 'package:aliuai_painel/services/plano_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_pix_screen.dart'; // Para formatar as datas e moedas bonitinho sô!
// Certifique-se de importar a sua tela de Checkout aqui sô!
// import 'package:aliuai_painel/screens/checkout_pix_screen.dart';

class MeusPagamentosScreen extends StatefulWidget {
  final String lojaId;

  const MeusPagamentosScreen({super.key, required this.lojaId});

  @override
  State<MeusPagamentosScreen> createState() => _MeusPagamentosScreenState();
}

class _MeusPagamentosScreenState extends State<MeusPagamentosScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _gerandoFatura = false;

  List<Map<String, dynamic>> _planosDoBanco = [];
  bool _carregandoPlanos = true;

  // Variables de controle do fluxo de desvio para a tela de Checkout sô!
  bool _mostrarPix = false;
  String _idPagamentoGerado = '';

  @override
  void initState() {
    super.initState();
    _carregarPlanosDoBanco();
  }

  /// Carrega os preços e limites direto da collection 'planos'
  Future<void> _carregarPlanosDoBanco() async {
    final planos = await PlanoService.buscarPlanosAtivos();
    if (mounted) {
      setState(() {
        _planosDoBanco = planos;
        _carregandoPlanos = false;
      });
    }
  }

  /// Executa a renovação mensal com os dados 100% dinâmicos do banco sô!
  Future<void> _renovarMensalidadeAtual(String nomeLoja, String planoAtualId) async {
    setState(() => _gerandoFatura = true);

    final dadosPlanoNoBanco = _planosDoBanco.firstWhere((p) => p['id'].toString().toLowerCase() == planoAtualId.toLowerCase(), orElse: () => {});

    if (dadosPlanoNoBanco.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível encontrar as configurações deste plano no banco sô!'), backgroundColor: Colors.red));
      setState(() => _gerandoFatura = false);
      return;
    }

    double valorPlano = dadosPlanoNoBanco['valor'];
    int limiteProd = dadosPlanoNoBanco['limite_produtos'];
    int limitePromo = dadosPlanoNoBanco['limite_promocoes'];

    if (valorPlano == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seu plano atual é Grátis sô! Não precisa gerar Pix de renovação.'), backgroundColor: Colors.amber));
      setState(() => _gerandoFatura = false);
      return;
    }

    String? pagamentoId = await PlanoService.iniciarMudancaDePlano(
      lojaId: widget.lojaId,
      nomeLoja: nomeLoja,
      idNovoPlano: planoAtualId,
      limiteProd: limiteProd,
      limitePromo: limitePromo,
      valorPlano: valorPlano,
    );

    setState(() => _gerandoFatura = false);

    if (pagamentoId != null && mounted) {
      setState(() {
        _idPagamentoGerado = pagamentoId;
        _mostrarPix = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarPix) {
      return CheckoutPixScreen(
        pagamentoId: _idPagamentoGerado,
        onVoltar: () {
          setState(() {
            _mostrarPix = false;
          });
          _carregarPlanosDoBanco();
        },
      );
    }

    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _carregandoPlanos
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(ehCelular ? 16.0 : 32.0),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('estabelecimentos').doc(widget.lojaId).snapshots(),
                builder: (context, snapshotLoja) {
                  if (snapshotLoja.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                  }

                  if (!snapshotLoja.hasData || !snapshotLoja.data!.exists) {
                    return const Center(child: Text('Erro ao carregar dados financeiros da loja sô! 🌾'));
                  }

                  final dadosLoja = snapshotLoja.data!.data() as Map<String, dynamic>;

                  String nomeLoja = dadosLoja['nome'] ?? 'Minha Loja';
                  String planoAtualId = dadosLoja['plano_atual'] ?? 'inicial';
                  String statusPagamento = dadosLoja['status_pagamento'] ?? 'pendente';

                  String vencimentoFormatado = 'Não disponível';
                  if (dadosLoja['proximo_vencimento'] != null) {
                    try {
                      DateTime dt = DateTime.parse(dadosLoja['proximo_vencimento']);
                      vencimentoFormatado = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                    } catch (_) {}
                  }

                  Color corStatus = Colors.grey;
                  String textoStatus = 'Pendente';
                  if (statusPagamento == 'em_dia') {
                    corStatus = Colors.green;
                    textoStatus = '🟢 EM DIA';
                  } else if (statusPagamento == 'pendente') {
                    corStatus = Colors.amber[800]!;
                    textoStatus = '🟡 PENDENTE';
                  } else if (statusPagamento == 'atrasado') {
                    corStatus = Colors.red;
                    textoStatus = '🔴 ATRASADO';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gestão Financeira & Plano',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                      ),
                      const SizedBox(height: 24),

                      // Card do Plano Atual
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: ehCelular
                              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: _construirDadosPlano(planoAtualId, textoStatus, corStatus, vencimentoFormatado, nomeLoja))
                              : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: _construirDadosPlano(planoAtualId, textoStatus, corStatus, vencimentoFormatado, nomeLoja)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 🚀 NOVA SEÇÃO: Histórico de Pagamentos Realizados sô!
                      const Text(
                        'Histórico de Faturamento',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                      ),
                      const SizedBox(height: 12),

                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('pagamentos')
                            .where('loja_id', isEqualTo: widget.lojaId)
                            .orderBy('criadoEm', descending: true) // Lembra de criar o índice composto sô!
                            .snapshots(),
                        builder: (context, snapshotPagamentos) {
                          if (snapshotPagamentos.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
                            );
                          }

                          if (snapshotPagamentos.hasError) {
                            print(snapshotPagamentos.error);
                          }

                          if (!snapshotPagamentos.hasData || snapshotPagamentos.data!.docs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: const Center(
                                child: Text('Nenhum pagamento registrado até o momento sô! 💸', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }

                          final faturas = snapshotPagamentos.data!.docs;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: faturas.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              itemBuilder: (context, index) {
                                final fatura = faturas[index].data() as Map<String, dynamic>;
                                final faturaId = faturas[index].id;

                                final double valor = (fatura['valor'] ?? 0.0).toDouble();
                                final String status = fatura['status'] ?? 'pendente';
                                final String novoPlano = fatura['idNovoPlano'] ?? 'Mensalidade';

                                // Trata a data de criação sô
                                String dataCriacao = 'Sem data';
                                if (fatura['criadoEm'] != null) {
                                  try {
                                    if (fatura['criadoEm'] is Timestamp) {
                                      DateTime dt = (fatura['criadoEm'] as Timestamp).toDate();
                                      dataCriacao =
                                          "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                                    }
                                  } catch (_) {}
                                }

                                // Define a cor e visual do Badge com base no status da fatura uai
                                Color corBadge = Colors.grey;
                                String txtBadge = status.toUpperCase();
                                if (status == 'pago') {
                                  corBadge = Colors.green;
                                  txtBadge = '🟢 PAGO';
                                } else if (status == 'pendente') {
                                  corBadge = Colors.orange;
                                  txtBadge = '⚡ PENDENTE';
                                } else if (status == 'cancelado') {
                                  corBadge = Colors.redAccent;
                                  txtBadge = '🛑 CANCELADO';
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: corBadge.withOpacity(0.1),
                                    child: Icon(status == 'pago' ? Icons.check_circle_rounded : (status == 'cancelado' ? Icons.cancel_rounded : Icons.pix_rounded), color: corBadge),
                                  ),
                                  title: Text('Renovação Plano ${novoPlano.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    key: ValueKey(faturaId),
                                    child: Text('Gerado em: $dataCriacao\nID: $faturaId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'R\$ ${valor.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E26)),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: corBadge.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          txtBadge,
                                          style: TextStyle(color: corBadge, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 💡 SACADA DE MESTRE: Se o cara clicar em uma fatura que ainda está pendente, reabre o CheckoutPixScreen!
                                  onTap: status == 'pendente'
                                      ? () {
                                          setState(() {
                                            _idPagamentoGerado = faturaId;
                                            _mostrarPix = true;
                                          });
                                        }
                                      : null,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  List<Widget> _construirDadosPlano(String planoId, String textoStatus, Color corStatus, String vencimento, String nomeLoja) {
    String nomePlanoBonito = _planosDoBanco.firstWhere((p) => p['id'].toString().toLowerCase() == planoId.toLowerCase(), orElse: () => {'nome': 'Não Definido'})['nome'];

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plano Atual: $nomePlanoBonito', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Situação: ', style: TextStyle(color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: corStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  textoStatus,
                  style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'Próximo Vencimento: ',
                  style: TextStyle(color: Colors.grey),
                ),
                TextSpan(
                  text: vencimento,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20, width: 20),

      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: _gerandoFatura ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.receipt_long_rounded),
        label: const Text('Pagar / Renovar Mensalidade', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _gerandoFatura ? null : () => _renovarMensalidadeAtual(nomeLoja, planoId),
      ),
    ];
  }
}
