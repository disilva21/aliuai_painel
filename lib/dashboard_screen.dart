import 'package:aliuai_painel/pedidos_screen.dart';
import 'package:aliuai_painel/services/plano_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importações das suas telas filhas (ajuste os caminhos conforme seu projeto)
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

  @override
  void initState() {
    super.initState();

    _inicializarPainel();
  }

  /// 🔥 Fonte Única da Verdade: Busca os dados uma única vez e distribui
  Future<void> _inicializarPainel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Busca o estabelecimento filtrando pelo campo 'uid' do nó de Auth
      final querySnapshot = await FirebaseFirestore.instance.collection('estabelecimentos').where('uid', isEqualTo: user.uid).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        final docLoja = querySnapshot.docs.first;
        final dadosLoja = docLoja.data();

        // 2. Captura e armazena o ID de documento real (ID automático do Firebase)
        _lojaIdReal = docLoja.id;

        // 3. Processamento das regras de negócio do Banner de Cobrança
        _statusPagamentoGeral = dadosLoja['status_pagamento'] ?? 'pendente';
        final Timestamp? timestampVencimento = dadosLoja['proximo_vencimento'];

        // REGRA 1: Se for ISENTO, esconde o banner permanentemente
        if (_statusPagamentoGeral == 'isento') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 999;
        }
        // REGRA 2: Se for PENDENTE (Novo cadastro feito pelo Admin ou Dono)
        else if (_statusPagamentoGeral == 'pendente') {
          _mostrarBannerPeriodoDeGraca = true;
          _diasRestantesParaVencer = 0;
          _abaSelecionada = 3; // Opcional: Redireciona para aba Perfil para o lojista ver os dados
        }
        // REGRA 3: Se for EM_DIA ou ATRASADO, calcula com base na data de vencimento
        else {
          if (timestampVencimento != null) {
            final dataVencimento = timestampVencimento.toDate();
            final dataHoje = DateTime.now();

            // Normaliza as datas para desconsiderar horas/minutos no cálculo dos dias
            final hojeApenasData = DateTime(dataHoje.year, dataHoje.month, dataHoje.day);
            final vencimentoApenasData = DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day);

            _diasRestantesParaVencer = vencimentoApenasData.difference(hojeApenasData).inDays;

            // Ativa o banner se faltar 7 dias ou menos, ou se o status master já for 'atrasado'
            if (_diasRestantesParaVencer <= 7 || _statusPagamentoGeral == 'atrasado') {
              _mostrarBannerPeriodoDeGraca = true;
            } else {
              _mostrarBannerPeriodoDeGraca = false;
            }
          } else {
            // Caso de contingência se o status for em_dia mas não houver data salva
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

  /// Método simulado para abrir o fluxo de pagamento
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
              Navigator.pop(context); // Fecha o modal

              _abaSelecionada = 4;
              setState(() {});
            },
            child: const Text('Visitar Agora', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoDadosLoja) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );
    }

    // Gatilhos para estilização do Banner de aviso
    bool contaBloqueadaOuAtrasada = _statusPagamentoGeral == 'atrasado' || (_statusPagamentoGeral != 'isento' && _diasRestantesParaVencer < 0);
    bool contaNovaPendente = _statusPagamentoGeral == 'pendente';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ⚠️ BANNER DE COBRANÇA INTELIGENTE (Nunca exibe se for 'isento')
          if (_statusPagamentoGeral != 'isento' && _mostrarBannerPeriodoDeGraca)
            InkWell(
              onTap: _abrirModalPagamentoPix,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                // Vermelho para bloqueados/atrasados. Laranja para avisos ou novos pendentes.
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

          // CORPO PRINCIPAL DO PAINEL (Sidebar + Telas Dinâmicas)
          Expanded(
            child: Row(
              children: [
                // 🧭 MENU LATERAL (SIDEBAR DE EXEMPLO - MANTENHA A SUA ESTRUTURA ATUAL)
                Container(
                  width: 250,
                  color: const Color(0xFF1E1E26),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'aliuai Admin',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      _buildItemMenu(index: 0, titulo: 'Pedidos', icone: Icons.delivery_dining_rounded),
                      _buildItemMenu(index: 1, titulo: 'Produtos', icone: Icons.shopping_bag_outlined),
                      _buildItemMenu(index: 2, titulo: 'Promoções', icone: Icons.local_offer_outlined),
                      _buildItemMenu(index: 3, titulo: 'Meu Perfil', icone: Icons.storefront_outlined),
                      _buildItemMenu(index: 4, titulo: 'Planos de Assinatura', icone: Icons.rocket_launch_outlined),
                      _buildItemMenu(index: 5, titulo: 'Segurança', icone: Icons.lock_outline),

                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 🖥️ VISUALIZADOR DE TELAS (INDEXED STACK)
                Expanded(
                  child: IndexedStack(
                    index: _abaSelecionada,
                    // 🔥 Passa o ID automático da loja já mastigado para todas as sub-telas
                    children: [
                      PedidosScreen(lojaId: _lojaIdReal!),
                      ProdutosScreen(lojaId: _lojaIdReal!), // Aba 0
                      PromocoesScreen(lojaId: _lojaIdReal!), // Aba 1
                      PerfilStoreScreen(lojaId: _lojaIdReal!), // Aba 2
                      PlanosScreen(lojaId: _lojaIdReal!), // Aba 3
                      const SegurancaScreen(), // Aba 4 (Se não precisar do ID)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construtor auxiliar de itens do menu lateral
  Widget _buildItemMenu({required int index, required String titulo, required IconData icone}) {
    final bool selecionado = _abaSelecionada == index;
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
      },
    );
  }
}
