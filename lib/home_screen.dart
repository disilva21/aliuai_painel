import 'package:aliuai_painel/caderneta_fiado_screen.dart';
import 'package:aliuai_painel/equipe.dart';
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
  final String? lojaId;
  const HomeScreen({super.key, required this.lojaId});

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
  String nivelAcessoAtual = 'operador'; // Valor padrão, será atualizado ao buscar os dados do usuário

  // 🛰️ DISPOSITIVO DE SEGURANÇA: Guarda a assinatura do listener para fechar no dispose sô!
  StreamSubscription<QuerySnapshot>? _pedidosSubscription;

  // Variáveis de controle do motor financeiro / banner
  String _statusPagamentoGeral = 'pendente';
  int _diasRestantesParaVencer = 0;
  bool _mostrarBannerPeriodoDeGraca = false;
  bool _exibindoOnboarding = false;

  // 🚀 O COMBO DAS TELAS CONGELADAS: Evita que o construtor das telas rode a cada clique de menu!
  final List<Widget?> _telasInstanciadas = List.generate(11, (index) => null);

  @override
  void initState() {
    super.initState();
    _verificarPrimeiroAcesso();
    _inicializarPainel(); // 🔥 Ele vai puxar os dados e ligar o som na hora certa!
  }

  @override
  void dispose() {
    _pedidosSubscription?.cancel(); // ✂️ Corta a torneira de dados do Firebase ao sair!
    _audioPlayer.dispose(); // Limpa o player da memória sô!
    super.dispose();
  }

  Future<void> _verificarTrocaSenha(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('funcionarios').doc(user.uid).get();

    if (doc.exists && doc.data()!['precisa_trocar_senha'] == true) {
      // Abre modal que não fecha (barrierDismissible: false)
      showDialog(context: context, barrierDismissible: false, builder: (context) => _buildModalTrocaSenha(context));
    }
  }

  Widget _buildModalTrocaSenha(BuildContext context) {
    final novaSenhaController = TextEditingController();
    bool carregandoSalvar = false;

    return StatefulBuilder(
      builder: (context, setStateModal) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.lock_reset, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Troca de Senha', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Como é seu primeiro acesso, precisamos que defina uma nova senha para sua segurança sô!', style: TextStyle(color: Colors.black87, fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: novaSenhaController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                hintText: 'Mínimo de 6 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: carregandoSalvar
                  ? null
                  : () async {
                      final senha = novaSenhaController.text.trim();
                      if (senha.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha precisa ter pelo menos 6 caracteres sô!'), backgroundColor: Colors.red));
                        return;
                      }

                      setStateModal(() => carregandoSalvar = true);

                      try {
                        // 1. Atualiza no Auth
                        await FirebaseAuth.instance.currentUser!.updatePassword(senha);

                        // 2. Atualiza no Firestore para liberar o uso
                        await FirebaseFirestore.instance.collection('funcionarios').doc(FirebaseAuth.instance.currentUser!.uid).update({'precisa_trocar_senha': false});

                        if (context.mounted) Navigator.pop(context); // Fecha o modal
                      } catch (e) {
                        setStateModal(() => carregandoSalvar = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar senha: $e'), backgroundColor: Colors.red));
                      }
                    },
              child: carregandoSalvar
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar e Acessar', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
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
        case 10:
          _telasInstanciadas[index] = EquipeScreen(lojaId: _lojaIdReal!);
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

      String? lojaIdFinal = widget.lojaId;
      Map<String, dynamic>? dadosLoja;

      // 1. TENTA ACHAR NA COLEÇÃO 'estabelecimentos' (Caso seja o Dono)
      final queryDono = await FirebaseFirestore.instance.collection('estabelecimentos').where('uid', isEqualTo: user.uid).limit(1).get();

      if (queryDono.docs.isNotEmpty) {
        final docLoja = queryDono.docs.first;
        lojaIdFinal ??= docLoja.id;
        dadosLoja = docLoja.data();
        nivelAcessoAtual = 'dono'; // Atualiza o nível de acesso para dono
      } else {
        // 2. SE NÃO ACHOU, É FUNCIONÁRIO! Vamos buscar na coleção 'funcionarios'
        final docFunc = await FirebaseFirestore.instance.collection('funcionarios').doc(user.uid).get();

        if (docFunc.exists) {
          final dadosFunc = docFunc.data()!;
          // Pega o ID da loja vinculado ao funcionário
          lojaIdFinal = dadosFunc['estabelecimento_id'];
          nivelAcessoAtual = dadosFunc['nivel_acesso'] ?? 'operador'; // Atualiza o nível de acesso para o funcionário

          // Agora sim, busca os dados da loja real usando esse ID!
          if (lojaIdFinal != null) {
            final docLojaReal = await FirebaseFirestore.instance.collection('estabelecimentos').doc(lojaIdFinal).get();

            if (docLojaReal.exists) {
              dadosLoja = docLojaReal.data();
            }
          }
        }
      }

      // 3. SE ENCONTROU OS DADOS DA LOJA (seja dono ou funcionário), POPULA A TELA
      if (dadosLoja != null && lojaIdFinal != null) {
        _lojaIdReal = lojaIdFinal;
        _nomeLoja = dadosLoja['nome'] ?? _lojaIdReal;
        _statusPagamentoGeral = dadosLoja['status_pagamento'] ?? 'pendente';

        // 🚜 AJUSTE DA ABA INICIAL BASEADA NO PERFIL SÔ!
        // Se a aba selecionada atual for 0 (Dashboard) mas o usuário não for gerente/dono, redireciona!
        if (_abaSelecionada == 0 && nivelAcessoAtual != 'dono' && nivelAcessoAtual != 'gerente') {
          if (nivelAcessoAtual == 'operador') {
            _abaSelecionada = 1; // Vai para 'Pedidos'
          } else if (nivelAcessoAtual == 'estoquista') {
            _abaSelecionada = 2; // Vai para 'Produtos'
          } else {
            _abaSelecionada = 1; // Padrão seguro para outros perfis
          }
        }

        // 🚀 LIGA O SOM: Com o ID real na mão, ligamos a escuta do som!
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
    await _verificarTrocaSenha(context);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
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
        ),
        lineDivider(), // 🚜 A linha agora vai colada embaixo de cada item!
      ],
    );
  }

  bool _deveMostrarMenu(int index, String? nivelAcesso) {
    // Se for dono (se o nivel for nulo ou vazio porque veio da collection de estabelecimentos)
    if (nivelAcesso == null || nivelAcesso == 'dono') return true;

    switch (index) {
      case 0: // Dashboard
      case 3: // Promoções
      case 5: // Meu Perfil

      case 10: // Equipe
        return nivelAcesso == 'gerente';

      case 1: // Pedidos
      case 4: // Eventos
      case 7: // Cardeneta Fiado
        return nivelAcesso == 'gerente' || nivelAcesso == 'operador';

      case 2: // Produtos
        return nivelAcesso == 'gerente' || nivelAcesso == 'estoquista';

      case 9: // Segurança (Disponível para todos trocarem a senha sô!)
        return true;

      case 6: // Planos
      case 8: // Pagamentos
        return false; // Funcionário nenhum vê financeiro do sistema/assinatura

      default:
        return false;
    }
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
                'Painel Aliuai',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            if (_deveMostrarMenu(0, nivelAcessoAtual)) _buildItemMenu(index: 0, titulo: 'Dashboard', icone: Icons.analytics_outlined),

            if (_deveMostrarMenu(1, nivelAcessoAtual)) _buildItemMenu(index: 1, titulo: 'Pedidos', icone: Icons.delivery_dining_rounded),

            if (_deveMostrarMenu(2, nivelAcessoAtual)) _buildItemMenu(index: 2, titulo: 'Produtos', icone: Icons.shopping_bag_outlined),

            if (_deveMostrarMenu(3, nivelAcessoAtual)) _buildItemMenu(index: 3, titulo: 'Promoções', icone: Icons.local_offer_outlined),

            if (_deveMostrarMenu(4, nivelAcessoAtual)) _buildItemMenu(index: 4, titulo: 'Eventos', icone: Icons.add_location_alt_outlined),

            if (_deveMostrarMenu(5, nivelAcessoAtual)) _buildItemMenu(index: 5, titulo: 'Meu Perfil', icone: Icons.storefront_outlined),

            if (_deveMostrarMenu(6, nivelAcessoAtual)) _buildItemMenu(index: 6, titulo: 'Planos de Assinatura', icone: Icons.rocket_launch_outlined),

            if (_deveMostrarMenu(7, nivelAcessoAtual)) _buildItemMenu(index: 7, titulo: 'Cardeneta Fiado', icone: Icons.menu_book_rounded),

            if (_deveMostrarMenu(8, nivelAcessoAtual)) _buildItemMenu(index: 8, titulo: 'Meu Pagamentos', icone: Icons.receipt_long_rounded),

            if (_deveMostrarMenu(9, nivelAcessoAtual)) _buildItemMenu(index: 9, titulo: 'Segurança', icone: Icons.lock_outline),

            if (_deveMostrarMenu(10, nivelAcessoAtual)) _buildItemMenu(index: 10, titulo: 'Equipe', icone: Icons.group_outlined),

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
                _nomeLoja ?? 'Painel Aliuai',
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
          if (_statusPagamentoGeral != 'isento' && _mostrarBannerPeriodoDeGraca && _statusPagamentoGeral != 'gratuito')
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
                            _obterTelaCongelada(10),
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
