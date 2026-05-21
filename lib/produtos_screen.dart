import 'package:aliuai_painel/dashboard_screen.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cadastro_produto_modal.dart';

class ProdutosScreen extends StatefulWidget {
  final String? lojaId;

  const ProdutosScreen({super.key, required this.lojaId});

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  final _firestore = FirebaseFirestore.instance;
  int _limiteProdutos = 0;
  int _produtosCadastrados = 0;

  @override
  void initState() {
    super.initState();
    _buscarLimiteDeProdutos();
  }

  // Altera a disponibilidade do produto direto no clique do Switch
  Future<void> _alternarDisponibilidade(String produtoId, bool statusAtual) async {
    try {
      await FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').doc(produtoId).update({'disponivel': !statusAtual});
    } catch (e) {
      print('Erro ao atualizar produto, sô: $e');
    }
  }

  /// 🔥 MODAL DE CONTRATAÇÃO DE NOVO PLANO (UPSELL)
  void _mostrarAlertaLimiteExcedido() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.amber[800], size: 28),
              const SizedBox(width: 12),
              const Text('Limite Atingido! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sua loja já atingiu o limite máximo de produtos cadastrados em seu plano atual.', style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Faça upgrade em seu plano agora mesmo!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Agora não', style: TextStyle(color: Colors.grey)),
            ),

            // BOTÃO 1: LEVA DIRETO PARA A TELA DE PLANOS DO SEU PAINEL
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context); // Fecha a modal

                // MUDANÇA DE ABA: Se a sua DashboardScreen gerencia as abas,
                // você pode disparar um callback ou avisar o lojista para ir até lá.
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Clique na aba "Planos de Assinatura" no menu lateral para escolher seu novo plano! 😉'), backgroundColor: Colors.blue));
              },
              child: const Text('Ver Planos'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buscarLimiteDeProdutos() async {
    try {
      // 1. Busca o documento do estabelecimento para pegar o limite do plano
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      int limiteRecuperado = 0;
      if (docLoja.exists) {
        limiteRecuperado = docLoja.data()?['limite_produtos'] ?? 0;
      }

      // 2. 🔥 CONTADOR OTIMIZADO: Conta quantos produtos existem na subcollection daquela loja
      // O .count().get() roda direto no servidor do Firebase e devolve só o número total
      final snapshotContagem = await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').count().get();

      int totalProdutos = snapshotContagem.count ?? 0;

      // 3. Atualiza o estado da tela de uma vez só se a tela ainda estiver aberta
      if (mounted) {
        setState(() {
          _limiteProdutos = limiteRecuperado;
          _produtosCadastrados = totalProdutos;
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar limites de produtos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lojaId == null) return const Center(child: Text('Loja não identificada.'));

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de Cabeçalho
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gerenciador de Cardápio / Catálogo',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 4),
                  Text('Ative ou pause seus itens cadastrados em tempo real.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              // BOTÃO ADICIONAR PRODUTO
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Novo Produto', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (_produtosCadastrados >= _limiteProdutos) {
                    _mostrarAlertaLimiteExcedido();
                    return;
                  }
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => CadastroProdutoModal(lojaId: widget.lojaId!),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // TABELA DE PRODUTOS DA SUBCOLEÇÃO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Erro ao carregar os dados.'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                }

                final produtos = snapshot.data?.docs ?? [];

                if (produtos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum produto cadastrado ainda, uai!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListView.separated(
                    itemCount: produtos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = produtos[index];
                      final dados = item.data() as Map<String, dynamic>;

                      String nome = dados['nome'] ?? 'Sem nome';
                      double preco = (dados['preco'] ?? 0.0).toDouble();
                      bool disponivel = dados['disponivel'] ?? true;
                      String descricao = dados['descricao'] ?? '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            descricao,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                        trailing: SizedBox(
                          width: 260,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 24),
                              Switch(value: disponivel, activeColor: const Color(0xFFE65100), onChanged: (val) => _alternarDisponibilidade(item.id, disponivel)),
                              Container(
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 24),
                                  tooltip: 'Editar Produto',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => CadastroProdutoModal(lojaId: widget.lojaId!, produtoExistente: item.data() as Map<String, dynamic>?, idProduto: item.id),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
