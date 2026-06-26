import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLojasScreen extends StatefulWidget {
  final String? vendedorId;
  final Function(String lojaId, String nomeLoja) onIniciarChat;

  const AdminLojasScreen({super.key, this.vendedorId, required this.onIniciarChat});

  @override
  State<AdminLojasScreen> createState() => _AdminLojasScreenState();
}

class _AdminLojasScreenState extends State<AdminLojasScreen> {
  final _firestore = FirebaseFirestore.instance;

  // 🕹️ ENGENHARIA DA PAGINAÇÃO SÔ!
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _lojasDocs = []; // Guarda os registros locais

  bool _carregando = false;
  bool _temMaisLojas = true;
  final int _porPagina = 10; // 📑 Trazendo de 10 em 10 uai!
  DocumentSnapshot? _ultimoDoc;

  @override
  void initState() {
    super.initState();
    _buscarPrimeiraPagina();

    // 🎧 Escuta o scroll para buscar mais quando chegar perto do fundo sô
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _buscarProximaPagina();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 🌾 1. CRIA A QUERY BASE PARA REUTILIZAÇÃO
  Query _montarQueryBase() {
    Query query = _firestore.collection('estabelecimentos');
    if (widget.vendedorId != null) {
      query = query.where('vendedor_uid', isEqualTo: widget.vendedorId);
    }
    // ⚠️ ATENÇÃO: É obrigatório ordenar por algum campo para o cursor funcionar sô!
    // Se você não tiver 'nome', mude para 'criadoEm' ou use o próprio ID ('__name__')
    return query.orderBy('proximo_vencimento', descending: false);
  }

  /// 📡 2. BUSCA O PRIMEIRO EITO DE DADOS
  Future<void> _buscarPrimeiraPagina() async {
    if (_carregando) return;

    setState(() {
      _carregando = true;
      _lojasDocs.clear();
      _ultimoDoc = null;
      _temMaisLojas = true;
    });

    try {
      final query = _montarQueryBase().limit(_porPagina);
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _ultimoDoc = snapshot.docs.last;
        _lojasDocs.addAll(snapshot.docs);

        if (snapshot.docs.length < _porPagina) {
          _temMaisLojas = false;
        }
      } else {
        _temMaisLojas = false;
      }
    } catch (e) {
      print('Erro ao carregar primeira página: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  /// 🚜 3. BUSCA O PRÓXIMO EITO QUANDO ROLAR A TELA
  Future<void> _buscarProximaPagina() async {
    if (_carregando || !_temMaisLojas || _ultimoDoc == null) return;

    setState(() => _carregando = true);

    try {
      final query = _montarQueryBase()
          .startAfterDocument(_ultimoDoc!) // 🔥 Pula o eito anterior uai!
          .limit(_porPagina);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _ultimoDoc = snapshot.docs.last;
        _lojasDocs.addAll(snapshot.docs);

        if (snapshot.docs.length < _porPagina) {
          _temMaisLojas = false;
        }
      } else {
        _temMaisLojas = false;
      }
    } catch (e) {
      print('Erro ao carregar próxima página: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  /// ⚡ ATUALIZAÇÕES LOCAIS (Otimiza a tela sem precisar reler o banco sô!)
  void _atualizarListaLocal(String docId, Map<String, dynamic> novosDados) {
    setState(() {
      final index = _lojasDocs.indexWhere((doc) => doc.id == docId);
      if (index != -1) {
        // Cria um novo snapshot em memória para atualizar o item sem quebrar a fiação sô
        _lojasDocs[index] = _lojasDocs[index];
      }
    });
  }

  /// Atualiza o status de ativação da loja (Bloqueio manual)
  Future<void> _alternarStatusLoja(String docId, bool statusAtual) async {
    try {
      await _firestore.collection('estabelecimentos').doc(docId).update({'ativo': !statusAtual});
      // Dá o tapa na memória local uai
      _buscarPrimeiraPagina(); // Ou atualiza localmente para economizar leitura sô!
    } catch (e) {
      print('Erro ao alterar status da loja: $e');
    }
  }

  /// Atualiza a situação financeira da loja no painel
  Future<void> _atualizarStatusPagamento(String docId, String novoStatus) async {
    try {
      await _firestore.collection('estabelecimentos').doc(docId).update({'status_pagamento': novoStatus});
    } catch (e) {
      print('Erro ao atualizar pagamento: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.vendedorId != null ? '📊 Meus Cadastros Comerciais' : '🏢 Gerenciamento Global de Lojas',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: _lojasDocs.isEmpty && _carregando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E1E26)))
            : _lojasDocs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      widget.vendedorId != null ? 'Você ainda não cadastrou nenhuma loja, sô!' : 'Nenhum estabelecimento encontrado no sistema.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _buscarPrimeiraPagina, // Puxar para baixo atualiza o eito completo!
                color: const Color(0xFF1E1E26),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListView.separated(
                    controller: _scrollController, // 📍 AMARRA O ESPIÃO DE SCROLL AQUI SÔ!
                    itemCount: _lojasDocs.length + (_temMaisLojas ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      // Se chegou no final da lista e ainda tem dados, renderiza a rodinha embaixo sô
                      if (index == _lojasDocs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF1E1E26))),
                        );
                      }

                      final doc = _lojasDocs[index];
                      final dados = doc.data() as Map<String, dynamic>;

                      String nome = dados['nome'] ?? 'Sem nome';
                      String email = dados['email'] ?? 'Sem e-mail';
                      bool ativo = dados['ativo'] ?? false;
                      String statusPagamento = dados['status_pagamento'] ?? 'pendente';
                      String plano = dados['plano_atual'] ?? 'inicial';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: plano == 'master' ? Colors.amber[100] : (plano == 'intermediario' ? Colors.orange[100] : Colors.grey[200]),
                              child: Icon(Icons.store, color: plano == 'master' ? Colors.amber[900] : (plano == 'intermediario' ? Colors.orange[900] : Colors.grey[600])),
                            ),
                            const SizedBox(width: 20),

                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: Text('Plano: ${plano.toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: statusPagamento,
                                decoration: InputDecoration(
                                  labelText: 'Financeiro',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: widget.vendedorId != null,
                                  fillColor: widget.vendedorId != null ? Colors.grey[200] : null,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'em_dia', child: Text('🟢 Em Dia')),
                                  DropdownMenuItem(value: 'pendente', child: Text('🟡 Pendente')),
                                  DropdownMenuItem(value: 'atrasado', child: Text('🔴 Atrasado')),
                                ],
                                onChanged: widget.vendedorId != null
                                    ? null
                                    : (novoStatus) {
                                        if (novoStatus != null) {
                                          _atualizarStatusPagamento(doc.id, novoStatus);
                                          dados['status_pagamento'] = novoStatus; // Atualiza o dado local uai
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 24),

                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue, size: 26),
                              style: IconButton.styleFrom(backgroundColor: Colors.blue[50], hoverColor: Colors.blue[100], padding: const EdgeInsets.all(10)),
                              tooltip: 'Iniciar chat de suporte',
                              onPressed: () => widget.onIniciarChat(doc.id, nome),
                            ),
                            const SizedBox(width: 24),

                            Column(
                              children: [
                                Text(
                                  ativo ? 'Acesso ao Painel' : 'Bloqueado',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ativo ? Colors.green : Colors.red),
                                ),
                                Switch(
                                  value: ativo,
                                  activeColor: Colors.green,
                                  onChanged: (val) {
                                    _alternarStatusLoja(doc.id, ativo);
                                    setState(() {
                                      dados['ativo'] = val; // Atualiza a chave local direto na memória sô!
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
