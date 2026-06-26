import 'dart:convert';
import 'package:aliuai_painel/caderneta_fiado_screen.dart';
import 'package:aliuai_painel/gerenciar_eventos_screen.dart';
import 'package:aliuai_painel/metrica_screen.dart';
import 'package:aliuai_painel/meus_pagamentos_screen.dart';
import 'package:aliuai_painel/onboarding_dialog.dart';
import 'package:aliuai_painel/pedidos_screen.dart';
import 'package:aliuai_painel/widget/botao_suporte_lojista.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async'; // 🛰️ Importante para gerenciar o cano da Stream sô!

// Importações das suas telas filhas
import 'produtos_screen.dart';
import 'promocoes_screen.dart';
import 'perfil_store_screen.dart';
import 'planos_screen.dart';
import 'seguranca_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<HomeScreen> {
  int _abaSelecionada = 0;
  String? _lojaIdReal;
  String? _nomeLoja;
  bool _carregandoDadosLoja = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _primeiraCarga = true;
  bool _somAtivado = true;

  // 🛰️ DISPOSITIVO DE SEGURANÇA: Guarda a assinatura do listener para fechar no dispose sô!
  StreamSubscription<QuerySnapshot>? _pedidosSubscription;

  // Variáveis de controle do motor financeiro / banner
  String _statusPagamentoGeral = 'pendente';
  int _diasRestantesParaVencer = 0;
  bool _mostrarBannerPeriodoDeGraca = false;
  bool _exibindoOnboarding = false;

  // 🚀 O COMBO DAS TELAS CONGELADAS: Evita que o construtor das telas rode a cada clique de menu!
  final List<Widget?> _telasInstanciadas = List.generate(10, (index) => null);

  @override
  void initState() {
    super.initState();
    _inicializarPainel(); // 🔥 Ele vai puxar os dados e ligar o som na hora certa!
    _verificarPrimeiroAcesso();
  }

  @override
  void dispose() {
    _pedidosSubscription?.cancel(); // ✂️ Corta a torneira de dados do Firebase ao sair!
    _audioPlayer.dispose(); // Limpa o player da memória sô!
    super.dispose();
  }

  /// ⚙️ MOTOR DEMANDA: Fabrica a tela uma única vez e trava ela na memória sô!
  Widget _obterTelaCongelada(int index) {
    if (_telasInstanciadas[index] == null && _lojaIdReal != null) {
      switch (index) {
        case 0:
          _telasInstanciadas[index] = MetricaScreen(lojaId: _lojaIdReal!);
          break;
        case 1:
          _telasInstanciadas[index] = PedidosScreen(lojaId: _lojaIdReal!);
          break;
        case 2:
          _telasInstanciadas[index] = ProdutosScreen(lojaId: _lojaIdReal!);
          break;
        case 3:
          _telasInstanciadas[index] = PromocoesScreen(lojaId: _lojaIdReal!);
          break;
        case 4:
          _telasInstanciadas[index] = GerenciarEventosPage(lojaId: _lojaIdReal!);
          break;
        case 5:
          // 🚀 CORREÇÃO DE OURO: O cache guarda APENAS a tela real do perfil sô!
          // Não deixamos o CircularProgressIndicator ser salvo aqui para não travar na memória.
          _telasInstanciadas[index] = PerfilStoreScreen(lojaId: _lojaIdReal!);
          break;
        case 6:
          _telasInstanciadas[index] = PlanosScreen(lojaId: _lojaIdReal!);
          break;
        case 7:
          _telasInstanciadas[index] = CadernetaFiadoScreen(lojaId: _lojaIdReal!);
          break;
        case 8:
          _telasInstanciadas[index] = MeusPagamentosScreen(lojaId: _lojaIdReal!);
          break;
        case 9:
          _telasInstanciadas[index] = const SegurancaScreen();
          break;
      }
    }

    // 🔥 Se a aba for a 5 (Perfil) e o Onboarding ainda estiver ativo na frente,
    // nós exibimos o loading dinamicamente sem sujar a variável de cache sô!
    if (index == 5 && _exibindoOnboarding) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    return _telasInstanciadas[index] ?? const SizedBox.shrink();
  }

  void _escutarNovosPedidos() {
    if (_lojaIdReal == null) return;

    _pedidosSubscription = FirebaseFirestore.instance
        .collection('pedidos')
        .where('estabelecimento_id', isEqualTo: _lojaIdReal)
        .where('status', isEqualTo: 'pendente') // Filtra apenas pedidos novos sô!
        .snapshots()
        .listen((snapshot) async {
          if (_primeiraCarga) {
            _primeiraCarga = false;
            return;
          }

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              if (_somAtivado) {
                try {
                  await _audioPlayer.play(AssetSource('sounds/notificacao.mp3'));
                } catch (e) {
                  print("Erro ao tocar som sô: $e");
                }
              }
            }
          }
        });
  }

  /// 🔥 Fonte Única da Verdade: Busca os dados uma única vez e distribui
  Future<void> _inicializarPainel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance.collection('estabelecimentos').where('uid', isEqualTo: user.uid).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        final docLoja = querySnapshot.docs.first;
        final dadosLoja = docLoja.data();

        _lojaIdReal = docLoja.id;
        _nomeLoja = dadosLoja['nome'] ?? _lojaIdReal;
        _statusPagamentoGeral = dadosLoja['status_pagamento'] ?? 'pendente';

        // 🚀 LIGA O SOM: Com o ID real na mão, ligamos a escuta do som sem perigo de nulo!
        _escutarNovosPedidos();

        final dynamic dadoVencimento = dadosLoja['proximo_vencimento'];
        Timestamp? timestampVencimento;

        if (dadoVencimento is Timestamp) {
          timestampVencimento = dadoVencimento;
        } else if (dadoVencimento is String) {
          final dateTimeConvertido = DateTime.tryParse(dadoVencimento);
          if (dateTimeConvertido != null) {
            timestampVencimento = Timestamp.fromDate(dateTimeConvertido);
          }
        }

        if (_statusPagamentoGeral == 'isento') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 999;
        } else if (_statusPagamentoGeral == 'teste') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 7;
        } else if (_statusPagamentoGeral == 'pendente') {
          _mostrarBannerPeriodoDeGraca = true;
          _diasRestantesParaVencer = 0;
          _abaSelecionada = 5; // Redireciona para os planos sô
        } else {
          if (timestampVencimento != null) {
            final dataVencimento = timestampVencimento.toDate();
            final dataHoje = DateTime.now();

            final hojeApenasData = DateTime(dataHoje.year, dataHoje.month, dataHoje.day);
            final vencimentoApenasData = DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day);

            _diasRestantesParaVencer = vencimentoApenasData.difference(hojeApenasData).inDays;

            if (_diasRestantesParaVencer <= 7 || _statusPagamentoGeral == 'atrasado') {
              _mostrarBannerPeriodoDeGraca = true;
            } else {
              _mostrarBannerPeriodoDeGraca = false;
            }
          } else {
            _mostrarBannerPeriodoDeGraca = false;
          }
        }
      }
    } catch (e) {
      print('Erro ao inicializar painel central da Dashboard: $e');
    }

    if (mounted) {
      setState(() => _carregandoDadosLoja = false);
    }
  }

  Future<void> _verificarPrimeiroAcesso() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool primeiroAcesso = prefs.getBool('primeiro_acesso_painel') ?? true;

    if (primeiroAcesso && mounted) {
      setState(() {
        _exibindoOnboarding = true;
        _abaSelecionada = 5;
      });
      await prefs.setBool('primeiro_acesso_painel', false);

      await OnboardingDialog.mostrar(context);

      if (mounted) {
        setState(() {
          _exibindoOnboarding = false;
        });
      }
    }
  }

  /// Método para abrir o fluxo de pagamento
  void _abrirModalPagamentoPix() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pix, color: Colors.teal),
            SizedBox(width: 12),
            Text('Ativação / Renovação Pix'),
          ],
        ),
        content: const Text('Visite a tela de planos para escolher o plano ideal para sua loja e efetuar o pagamento via Pix.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _abaSelecionada = 6;
              });
            },
            child: const Text('Visitar Agora', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  /// 🛠️ Método de construção do item de menu sô
  Widget _buildItemMenu({required int index, required String titulo, required IconData icone}) {
    final bool selecionado = _abaSelecionada == index;
    final bool ehCelular = MediaQuery.of(context).size.width < 800;

    return ListTile(
      selected: selecionado,
      selectedTileColor: Colors.white.withOpacity(0.05),
      leading: Icon(icone, color: selecionado ? const Color(0xFFE65100) : Colors.grey),
      title: Text(
        titulo,
        style: TextStyle(color: selecionado ? Colors.white : Colors.grey, fontWeight: selecionado ? FontWeight.bold : FontWeight.normal),
      ),
      onTap: () {
        setState(() {
          _abaSelecionada = index;
        });

        if (ehCelular) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoDadosLoja) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );
    }

    final bool ehCelular = MediaQuery.of(context).size.width < 800;
    bool contaBloqueadaOuAtrasada = _statusPagamentoGeral == 'atrasado' || (_statusPagamentoGeral != 'isento' && _diasRestantesParaVencer < 0);
    bool contaNovaPendente = _statusPagamentoGeral == 'pendente';

    Widget construirMenuCompleto() {
      return Container(
        width: 250,
        color: const Color(0xFF1E1E26),
        child: ListView(
          children: [
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Painel aliuai',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            _buildItemMenu(index: 0, titulo: 'Dashboard', icone: Icons.analytics_outlined),
            lineDivider(),
            _buildItemMenu(index: 1, titulo: 'Pedidos', icone: Icons.delivery_dining_rounded),
            lineDivider(),
            _buildItemMenu(index: 2, titulo: 'Produtos', icone: Icons.shopping_bag_outlined),
            lineDivider(),
            _buildItemMenu(index: 3, titulo: 'Promoções', icone: Icons.local_offer_outlined),
            lineDivider(),
            _buildItemMenu(index: 4, titulo: 'Eventos', icone: Icons.add_location_alt_outlined),
            lineDivider(),
            _buildItemMenu(index: 5, titulo: 'Meu Perfil', icone: Icons.storefront_outlined),
            lineDivider(),
            _buildItemMenu(index: 6, titulo: 'Planos de Assinatura', icone: Icons.rocket_launch_outlined),
            lineDivider(),
            _buildItemMenu(index: 7, titulo: 'Cardeneta Fiado', icone: Icons.menu_book_rounded),
            lineDivider(),
            _buildItemMenu(index: 8, titulo: 'Meu Pagamentos', icone: Icons.receipt_long_rounded),
            lineDivider(),
            _buildItemMenu(index: 9, titulo: 'Segurança', icone: Icons.lock_outline),
            lineDivider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  if (ehCelular) Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final info = snapshot.data!;
                    return Text(
                      'Aliuai Painel\nv${info.version}-${info.buildNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500),
                    );
                  }

                  return const Text(
                    'Aliuai Painel\nVersão v1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: ehCelular ? Drawer(child: construirMenuCompleto()) : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: ehCelular,
        title: ehCelular
            ? Text(
                _nomeLoja ?? 'Painel AliUai',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              )
            : null,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('estabelecimentos').doc(_lojaIdReal).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              // Pega a variável 'aberto' do banco (se não existir, assume true)
              bool lojaAberta = snapshot.data!['aberto'] ?? true;

              return Row(
                children: [
                  // Texto dinâmico para o lojista ver o eito da porteira
                  Text(
                    lojaAberta ? "ABERTA 🟢" : "FECHADA 🔴",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  // O interruptor que desliga e liga a loja na marra
                  Switch(
                    value: lojaAberta,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    inactiveTrackColor: Colors.red.shade200,
                    onChanged: (novoStatus) async {
                      // Atualiza o banco de dados no mesmo milissegundo sô!
                      await FirebaseFirestore.instance.collection('estabelecimentos').doc(_lojaIdReal).update({'aberto': novoStatus});

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(novoStatus ? 'Porteira aberta! Boas vendas! 🌾' : 'Loja fechada com sucesso sô!'), duration: const Duration(seconds: 2)));
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 20),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: Icon(_somAtivado ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: _somAtivado ? Colors.green : Colors.grey[600]),
              tooltip: _somAtivado ? 'Desativar som dos pedidos' : 'Ativar som dos pedidos',
              onPressed: () {
                setState(() {
                  _somAtivado = !_somAtivado;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_somAtivado ? 'Alertas sonoros ativados! 🔊' : 'Painel silenciado! 🔇'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: _somAtivado ? Colors.green : Colors.black87,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statusPagamentoGeral != 'isento' && _mostrarBannerPeriodoDeGraca)
            InkWell(
              onTap: _abrirModalPagamentoPix,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                color: contaBloqueadaOuAtrasada ? Colors.red[700] : Colors.orange[700],
                child: Row(
                  children: [
                    Icon(contaBloqueadaOuAtrasada ? Icons.gavel_rounded : Icons.star_border_purple500_rounded, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contaBloqueadaOuAtrasada
                                ? 'MENSALIDADE VENCIDA - Efetue o pagamento para evitar a suspensão da sua loja!'
                                : contaNovaPendente
                                ? 'BEM-VINDO AO ALIUAI! 🎉 Sua conta está aguardando ativação.'
                                : 'RENOVAÇÃO DO PLANO - Sua mensalidade vence em $_diasRestantesParaVencer ${_diasRestantesParaVencer == 1 ? 'dia' : 'dias'}.',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            contaNovaPendente ? 'Clique aqui para pagar a primeira mensalidade e liberar seu catálogo para os clientes.' : 'Clique aqui para escolher o melhor plano para seu negócio.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    if (!ehCelular) construirMenuCompleto(),

                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(ehCelular ? 8 : 16),
                        child: IndexedStack(
                          index: _abaSelecionada,
                          children: [
                            _obterTelaCongelada(0),
                            _obterTelaCongelada(1),
                            _obterTelaCongelada(2),
                            _obterTelaCongelada(3),
                            _obterTelaCongelada(4),
                            _obterTelaCongelada(5),
                            _obterTelaCongelada(6),
                            _obterTelaCongelada(7),
                            _obterTelaCongelada(8),
                            _obterTelaCongelada(9),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                BotaoSuporteLojista(nomeLoja: _nomeLoja!, lojaId: _lojaIdReal!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Padding lineDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Divider(color: Colors.white10, height: 1),
    );
  }
}
