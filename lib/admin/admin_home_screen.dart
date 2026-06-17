import 'package:aliuai_painel/admin/central_suporte_admin_aba.dart';
import 'package:aliuai_painel/admin/painel_utilidades_screen.dart';
import 'package:aliuai_painel/admin_lojas_screen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminHomeScreen> {
  int _abaSelecionada = 0;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Variáveis de controle de acesso do Admin
  String _userRole = 'vendedor'; // Padrão seguro por contingência
  String? _currentUserUid;
  bool _carregandoPerfil = true;

  // 🚀 NOVO: Variáveis de estado para controlar o redirecionamento direto de chat uai!
  String? _idLojaAtalho;
  String? _nomeLojaAtalho;

  // Controllers para o cadastro de novas lojas
  final _nomeLojaController = TextEditingController();
  final _emailLojaController = TextEditingController();
  final _senhaProvisoriaController = TextEditingController();

  final _nomeUserController = TextEditingController();
  final _emailUserController = TextEditingController();
  final _senhaUserProvisoriaController = TextEditingController();
  String _roleSelecionada = 'vendedor';

  String? _categoriaSelecionadaId;
  List<Map<String, String>> _categoriasDisponiveis = [];

  @override
  void initState() {
    super.initState();
    _inicializarPainelAdmin();
  }

  /// Carrega os dados de perfil de quem está logado para aplicar os filtros de visualização
  Future<void> _inicializarPainelAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUserUid = user.uid;

        final queryUser = await _firestore.collection('usuarios').where('uid', isEqualTo: user.uid).limit(1).get();

        if (queryUser.docs.isNotEmpty && mounted) {
          final dadosUser = queryUser.docs.first.data();
          setState(() {
            _userRole = dadosUser['role'] ?? 'vendedor';
          });
        } else {
          print('Usuário não encontrado na coleção usuarios com o UID: ${user.uid}');
        }
      }

      await _carregarCategorias();
    } catch (e) {
      print('Erro ao inicializar dados do painel Admin: $e');
    } finally {
      if (mounted) {
        setState(() => _carregandoPerfil = false);
      }
    }
  }

  Future<void> _carregarCategorias() async {
    try {
      final snapshot = await _firestore.collection('categorias').get();
      setState(() {
        _categoriasDisponiveis = snapshot.docs.map((doc) {
          return {'id': doc.id, 'nome': (doc.data()['nome'] ?? '').toString()};
        }).toList();
      });
    } catch (e) {
      print('Erro ao carregar categorias no admin: $e');
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/admin', (route) => false);
    }
  }

  void _abrirModalCadastroLoja() {
    if (_categoriasDisponiveis.isNotEmpty) {
      _categoriaSelecionadaId = _categoriasDisponiveis.first['id'];
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_business, color: Color(0xFF1E1E26)),
                  SizedBox(width: 12),
                  Text('Cadastrar Nova Loja / Vendedor'),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('O documento da loja será criado no Firestore com status ATIVO e EM DIA por padrão.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nomeLojaController,
                      decoration: const InputDecoration(labelText: 'Nome do Estabelecimento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailLojaController,
                      decoration: const InputDecoration(labelText: 'E-mail do Lojista (Login)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaProvisoriaController,
                      decoration: const InputDecoration(labelText: 'Senha Provisória de Acesso', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionadaId,
                      decoration: const InputDecoration(labelText: 'Categoria Inicial', border: OutlineInputBorder()),
                      items: _categoriasDisponiveis.map((cat) {
                        return DropdownMenuItem<String>(value: cat['id'], child: Text(cat['nome']!));
                      }).toList(),
                      onChanged: (id) => setModalState(() => _categoriaSelecionadaId = id),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _limparCamposModal();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E26), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_nomeLojaController.text.isNotEmpty && _emailLojaController.text.isNotEmpty) {
                      await _salvarNovaLojaNoFirestore();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirmar e Criar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _limparCamposModal() {
    _nomeLojaController.clear();
    _emailLojaController.clear();
    _senhaProvisoriaController.clear();
  }

  void _abrirModalCadastroUsuario() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: Color(0xFF1E1E26)),
                  SizedBox(width: 12),
                  Text('Novo Usuário Administrativo'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cadastre um novo perfil para acessar este painel master.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nomeUserController,
                      decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailUserController,
                      decoration: const InputDecoration(labelText: 'E-mail de Acesso', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaUserProvisoriaController,
                      decoration: const InputDecoration(labelText: 'Senha Inicial Provisória', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _roleSelecionada,
                      decoration: const InputDecoration(labelText: 'Nível de Permissão', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'vendedor', child: Text('Vendedor / Comercial')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: (val) => setModalState(() => _roleSelecionada = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _nomeUserController.clear();
                    _emailUserController.clear();
                    _senhaUserProvisoriaController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E26), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_nomeUserController.text.isNotEmpty && _emailUserController.text.isNotEmpty) {
                      await _salvarNovoUsuarioNoFirestore();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _salvarNovoUsuarioNoFirestore() async {
    try {
      await _firestore.collection('usuarios').add({
        'nome': _nomeUserController.text.trim(),
        'email': _emailUserController.text.trim(),
        'senha_provisoria': _senhaUserProvisoriaController.text.trim(),
        'role': _roleSelecionada,
        'ativo': true,
        'criado_em': FieldValue.serverTimestamp(),
      });

      _nomeUserController.clear();
      _emailUserController.clear();
      _senhaUserProvisoriaController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membro da equipe cadastrado! 👤'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar usuário: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _salvarNovaLojaNoFirestore() async {
    try {
      await _firestore.collection('estabelecimentos').add({
        'nome': _nomeLojaController.text.trim(),
        'email': _emailLojaController.text.trim(),
        'senha_provisoria': _senhaProvisoriaController.text.trim(),
        'categoria_id': _categoriaSelecionadaId,
        'vendedor_uid': _currentUserUid,
        'ativo': false,
        'status_pagamento': 'pendente',
        'plano_atual': 'indefinido',
        'limite_produtos': 0,
        'limite_promocoes': 0,
        'is_delivery': false,
        'tempo_entrega': '',
        'criado_em': FieldValue.serverTimestamp(),
      });

      _limparCamposModal();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nova loja criada com sucesso! 🚀'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar registro da loja: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoPerfil) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // SIDEBAR MASTER (MENU LATERAL DO ADMIN)
              Container(
                width: 260,
                color: const Color(0xFF1E1E26),
                child: Column(
                  key: ValueKey(_abaSelecionada), // Ajuda o Flutter a reconstruir os estados de foco do menu lateral
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AliUai 🌌',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(_userRole == 'admin' ? 'Painel Master Admin' : 'Painel de Consultor / Vendedor', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 16),

                    // ITEM 1: LISTA DE LOJAS CADASTRADAS
                    ListTile(
                      leading: Icon(Icons.store_mall_directory, color: _abaSelecionada == 0 ? Colors.cyanAccent : Colors.grey),
                      title: Text(
                        _userRole == 'admin' ? 'Todas as Lojas' : 'Minhas Lojas Cadastradas',
                        style: TextStyle(color: _abaSelecionada == 0 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      tileColor: _abaSelecionada == 0 ? Colors.white.withOpacity(0.05) : Colors.transparent,
                      onTap: () => setState(() => _abaSelecionada = 0),
                    ),

                    // ITEM 2: BOTÃO DIRETO DE CADASTRO (AÇÃO RÁPIDA)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                      title: const Text(
                        'Cadastrar Loja',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      onTap: _abrirModalCadastroLoja,
                    ),

                    if (_userRole == 'admin')
                      ListTile(
                        leading: const Icon(Icons.person_add_alt_1, color: Colors.lightBlueAccent),
                        title: const Text(
                          'Cadastrar Vendedor',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        onTap: _abrirModalCadastroUsuario,
                      ),

                    if (_userRole == 'admin')
                      ListTile(
                        leading: Icon(Icons.location_city, color: _abaSelecionada == 2 ? Colors.cyanAccent : Colors.grey),
                        title: Text(
                          'Utilidades Locais',
                          style: TextStyle(color: _abaSelecionada == 2 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        tileColor: _abaSelecionada == 2 ? Colors.white.withOpacity(0.05) : Colors.transparent,
                        onTap: () => setState(() => _abaSelecionada = 2),
                      ),

                    // ITEM 5: CHAT SUPORTE
                    ListTile(
                      leading: Icon(Icons.chat_bubble_rounded, color: _abaSelecionada == 1 ? Colors.greenAccent : Colors.grey),
                      title: Text(
                        'Chat Suporte',
                        style: TextStyle(color: _abaSelecionada == 1 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      tileColor: _abaSelecionada == 1 ? Colors.white.withOpacity(0.05) : Colors.transparent,
                      onTap: () {
                        setState(() {
                          // ✨ COMPORTAMENTO SEGURO: Se clicar no menu manualmente,
                          // limpa o atalho para carregar a lista geral de conversas sô!
                          _idLojaAtalho = null;
                          _nomeLojaAtalho = null;
                          _abaSelecionada = 1;
                        });
                      },
                    ),
                    const Spacer(),
                    const Divider(color: Colors.white12, height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text(
                        'Sair do Sistema',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      onTap: _logout,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // CONTEÚDO PRINCIPAL (INDEXED STACK)
              Expanded(
                child: IndexedStack(
                  index: _abaSelecionada,
                  children: [
                    // ✨ INDEX 0: Tela de Gerenciamento de Lojas
                    AdminLojasScreen(
                      vendedorId: _userRole == 'vendedor' ? _currentUserUid : null,
                      // 🔥 AJUSTADO: Captura o clique do IconButton interno e redireciona uai!
                      onIniciarChat: (lojaId, nomeLoja) {
                        setState(() {
                          _idLojaAtalho = lojaId;
                          _nomeLojaAtalho = nomeLoja;
                          _abaSelecionada = 1; // 🚀 Pula o ponteiro direto para a aba de Suporte!
                        });
                      },
                    ),

                    // ✨ INDEX 1: Orquestrador da Central de Suporte
                    CentralSuporteAdminAba(idLojistaInicial: _idLojaAtalho, nomeLojaInicial: _nomeLojaAtalho),

                    // ✨ INDEX 2: Painel de Utilidades
                    const PainelUtilidadesPage(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
