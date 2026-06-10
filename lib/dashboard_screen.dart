import 'package:aliuai_painel/gerenciar_eventos_screen.dart';
import 'package:aliuai_painel/metrica_screen.dart';
import 'package:aliuai_painel/onboarding_dialog.dart';
import 'package:aliuai_painel/pedidos_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importações das suas telas filhas
import 'produtos_screen.dart';
import 'promocoes_screen.dart';
import 'perfil_store_screen.dart';
import 'planos_screen.dart';
import 'seguranca_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _abaSelecionada = 0;
  String? _lojaIdReal; // Guarda o ID automático real do Firestore (ex: ABCDE123)
  bool _carregandoDadosLoja = true;

  // Variáveis de controle do motor financeiro / banner
  String _statusPagamentoGeral = 'pendente';
  int _diasRestantesParaVencer = 0;
  bool _mostrarBannerPeriodoDeGraca = false;

  // 🔥 Rastreia quais abas já foram abertas pelo usuário sô!
  // Como são 8 telas no seu IndexedStack, começamos com 8 falsos.
  final List<bool> _abasCarregadas = List.generate(8, (index) => false);

  @override
  void initState() {
    super.initState();
    _inicializarPainel();
    _verificarPrimeiroAcesso();
  }

  Future<void> _verificarPrimeiroAcesso() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool primeiroAcesso = prefs.getBool('primeiro_acesso_painel') ?? true;

    if (primeiroAcesso && mounted) {
      OnboardingDialog.mostrar(context);
      await prefs.setBool('primeiro_acesso_painel', false); // 🔥 Corrigido para false para salvar que já viu sô!
    }
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

        _statusPagamentoGeral = dadosLoja['status_pagamento'] ?? 'pendente';
        final Timestamp? timestampVencimento = dadosLoja['proximo_vencimento'];

        if (_statusPagamentoGeral == 'isento') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 999;
        } else if (_statusPagamentoGeral == 'teste') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 7;
        } else if (_statusPagamentoGeral == 'pendente') {
          _mostrarBannerPeriodoDeGraca = true;
          _diasRestantesParaVencer = 0;
          _abaSelecionada = 6; // Redireciona para os planos sô
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
                _abaSelecionada = 6; // Mirando o index correto da PlanosScreen sô!
              });
            },
            child: const Text('Visitar Agora', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  /// 🛠️ SEU MÉTODO DE CONSTRUÇÃO DO ITEM DE MENU RECUPERADO AQUI SÔ!
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

    // 🔥 Ativa o carregamento da aba atual no momento do clique sô!
    _abasCarregadas[_abaSelecionada] = true;

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
            _buildItemMenu(index: 0, titulo: 'Dashboard', icone: Icons.analytics_outlined), // Alterado ícone para combinar com Métricas sô!
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
            _buildItemMenu(index: 7, titulo: 'Segurança', icone: Icons.lock_outline),
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
                            contaNovaPendente
                                ? 'Clique aqui para pagar a primeira mensalidade e liberar seu catálogo para os clientes.'
                                : 'Clique aqui para visualizar a chave Pix e manter o seu painel ativo.',
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
            child: Row(
              children: [
                if (!ehCelular) construirMenuCompleto(),

                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(ehCelular ? 8 : 16),
                    // 🛡️ O INDEXED STACK SEGURO E ECONÔMICO PLUGADO E PREPARADO!
                    child: IndexedStack(
                      index: _abaSelecionada,
                      children: [
                        _abasCarregadas[0] ? MetricaScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[1] ? PedidosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[2] ? ProdutosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[3] ? PromocoesScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[4] ? GerenciarEventosPage(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[5] ? PerfilStoreScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[6] ? PlanosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[7] ? const SegurancaScreen() : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
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
