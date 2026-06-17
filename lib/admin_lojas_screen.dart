import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLojasScreen extends StatefulWidget {
  final String? vendedorId; // ✨ Recebe o ID do vendedor (se for nulo, é Admin Master)
  final Function(String lojaId, String nomeLoja) onIniciarChat; // 🚀 GATILHO: Avisa a tela mãe para mudar de aba sô!

  const AdminLojasScreen({super.key, this.vendedorId, required this.onIniciarChat});

  @override
  State<AdminLojasScreen> createState() => _AdminLojasScreenState();
}

class _AdminLojasScreenState extends State<AdminLojasScreen> {
  final _firestore = FirebaseFirestore.instance;

  /// Atualiza o status de ativação da loja (Bloqueio manual do admin)
  Future<void> _alternarStatusLoja(String docId, bool statusAtual) async {
    try {
      await _firestore.collection('estabelecimentos').doc(docId).update({'ativo': !statusAtual});
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
    // 🔥 CONFIGURAÇÃO DA QUERY DINÂMICA
    Query queryLojas = _firestore.collection('estabelecimentos');

    if (widget.vendedorId != null) {
      // 🔒 Se for um vendedor, ele só escuta os seus próprios cadastros
      queryLojas = queryLojas.where('vendedor_uid', isEqualTo: widget.vendedorId);
    }

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
        child: StreamBuilder<QuerySnapshot>(
          stream: queryLojas.snapshots(), // Escuta o banco em tempo real filtrado
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF1E1E26)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
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
              );
            }

            final lojas = snapshot.data!.docs;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListView.separated(
                itemCount: lojas.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = lojas[index];
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
                        // Ícone Indicador de Tipo/Plano
                        CircleAvatar(
                          backgroundColor: plano == 'master' ? Colors.amber[100] : (plano == 'intermediario' ? Colors.orange[100] : Colors.grey[200]),
                          child: Icon(Icons.store, color: plano == 'master' ? Colors.amber[900] : (plano == 'intermediario' ? Colors.orange[900] : Colors.grey[600])),
                        ),
                        const SizedBox(width: 20),

                        // Dados da Loja
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

                        // Controle Financeiro (Dropdown de Status)
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
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 24),

                        // 🚀 NOVO: Botão instalado para o Admin iniciar a prosa direto sô!
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue, size: 26),
                          style: IconButton.styleFrom(backgroundColor: Colors.blue[50], hoverColor: Colors.blue[100], padding: const EdgeInsets.all(10)),
                          tooltip: 'Iniciar chat de suporte',
                          // Envia o doc.id (ID_LOJA) real e o nome sô!
                          onPressed: () => widget.onIniciarChat(doc.id, nome),
                        ),
                        const SizedBox(width: 24),

                        // Switch de Bloqueio/Ativação no App do Cliente
                        Column(
                          children: [
                            Text(
                              ativo ? 'Acesso ao Painel' : 'Bloqueado',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ativo ? Colors.green : Colors.red),
                            ),
                            Switch(value: ativo, activeColor: Colors.green, onChanged: (val) => _alternarStatusLoja(doc.id, ativo)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
