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
  int _limiteProdutosPlano = 0;
  int _produtosCadastradosTotal = 0;

  // 🔍 CONTROLES DE FILTRO E PAGINAÇÃO SÔ!
  String? _categoriaFiltroId; // Nulo significa "Todos os Produtos"
  int _limiteProdutosExibidos = 10; // Começa exibindo 10 itens sô
  bool _temMaisProdutos = true;

  // 📡 Lista de categorias vindas do banco genérico
  List<Map<String, dynamic>> _categoriasFiltroLista = [];
  bool _carregandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _buscarLimiteDeProdutos();
    _carregarCategoriasGlobais(); // 🔥 Puxa o catálogo genérico para o topo sô!
  }

  /// 🛠️ Busca a lista genérica/global do Firebase para o Dropdown do topo sô!
  Future<void> _carregarCategoriasGlobais() async {
    try {
      final snapshot = await _firestore.collection('categoria_produto').orderBy('nome').get();

      final List<Map<String, dynamic>> carregadas = snapshot.docs.map((doc) {
        return {'id': doc.id, 'nome': doc['nome'].toString()};
      }).toList();

      if (mounted) {
        setState(() {
          _categoriasFiltroLista = carregadas;
          _carregandoCategorias = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias no filtro sô: $e');
      if (mounted) setState(() => _carregandoCategorias = false);
    }
  }

  // Altera a disponibilidade do produto direto no clique do Switch
  Future<void> _alternarDisponibilidade(String produtoId, bool statusAtual) async {
    try {
      await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').doc(produtoId).update({'disponivel': !statusAtual});
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
              const Text('Sua loja já atingiu o limite máximo de produtos cadastrados em seu plano atual.', style: TextStyle(fontSize: 14, color: Colors.black87)),
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
                    const SizedBox(width: 12),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Clique na aba "Planos de Assinatura" no menu lateral para escolher seu novo plano! 😉'), backgroundColor: Colors.blue));
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buscarLimiteDeProdutos() async {
    try {
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      int limiteRecuperado = 0;
      if (docLoja.exists) {
        limiteRecuperado = docLoja.data()?['limite_produtos'] ?? 0;
      }

      final snapshotContagem = await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').count().get();
      int totalProdutos = snapshotContagem.count ?? 0;

      if (mounted) {
        setState(() {
          _limiteProdutosPlano = limiteRecuperado;
          _produtosCadastradosTotal = totalProdutos;
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
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de Cabeçalho Responsiva
          LayoutBuilder(
            builder: (context, constraints) {
              final bool ehCelular = constraints.maxWidth < 800;

              final Widget blocoTextos = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gerenciador de Cardápio / Catálogo',
                    style: TextStyle(fontSize: ehCelular ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text('Ative ou pause seus itens cadastrados em tempo real.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              );

              final Widget botaoNovo = SizedBox(
                width: ehCelular ? double.infinity : null,
                child: ElevatedButton.icon(
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
                    if (_produtosCadastradosTotal >= _limiteProdutosPlano) {
                      _mostrarAlertaLimiteExcedido();
                      return;
                    }
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => CadastroProdutoModal(lojaId: widget.lojaId!),
                    ).then((_) => _buscarLimiteDeProdutos()); // Recarrega contagem ao fechar sô!
                  },
                ),
              );

              if (ehCelular) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [blocoTextos, const SizedBox(height: 16), botaoNovo]);
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: blocoTextos),
                    const SizedBox(width: 16),
                    botaoNovo,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // 🔍 NOVO SELETOR DE CATEGORIA DO TOPO SÔ!
          _carregandoCategorias
              ? const LinearProgressIndicator(color: Color(0xFFE65100))
              : Container(
                  width: 300, // Largura elegante fixada para a caixa sô
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoriaFiltroId,
                      hint: const Text('Filtrar por Categoria', style: TextStyle(fontSize: 14)),
                      isExpanded: true,
                      icon: const Icon(Icons.filter_list_rounded, color: Color(0xFFE65100)),
                      items: [
                        // Primeira opção fixa para limpar o filtro sô!
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('👀 Mostrar Todas as Seções', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ..._categoriasFiltroLista.map((cat) {
                          return DropdownMenuItem<String>(value: cat['id'], child: Text(cat['nome']));
                        }),
                      ],
                      onChanged: (idSelecionado) {
                        setState(() {
                          _categoriaFiltroId = idSelecionado;
                          _limiteProdutosExibidos = 10; // Reseta a paginação ao trocar de categoria sô!
                        });
                      },
                    ),
                  ),
                ),

          const SizedBox(height: 24),

          // TABELA DE PRODUTOS DA SUBCOLEÇÃO COM FILTRO E PAGINAÇÃO DINÂMICA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                // 🧠 MONTAGEM DA QUERY INTELIGENTE SÔ:
                Query queryBase = _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').orderBy('nome'); // Ordenação base sô

                // Se tiver categoria selecionada, injeta a cláusula WHERE apontando pro ID genérico sô!
                if (_categoriaFiltroId != null) {
                  queryBase = queryBase.where('categoria_id', isEqualTo: _categoriaFiltroId);
                }

                // Aplica o limite da paginação dinâmica de 10 em 10 sô!
                return queryBase.limit(_limiteProdutosExibidos).snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return const Center(child: Text('Erro ao carregar os dados.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                }

                final produtosDocs = snapshot.data?.docs ?? [];

                if (produtosDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _categoriaFiltroId == null ? 'Nenhum produto cadastrado ainda, uai!' : 'Nenhum produto nesta seção sô! 🌾',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Se a quantia que veio do banco bate com o limite atual, indica que tem mais páginas na fila sô!
                _temMaisProdutos = produtosDocs.length == _limiteProdutosExibidos;

                return ListView.builder(
                  itemCount: produtosDocs.length + (_temMaisProdutos ? 1 : 0), // +1 é a vaga do botão carregar sô!
                  itemBuilder: (context, index) {
                    // ⏭️ LINHA DO BOTÃO "VER MAIS PRODUTOS" SÔ!
                    if (index == produtosDocs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: const BorderSide(color: Color(0xFFCCCCCC)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            label: const Text('Carregar próximos 10 produtos sô', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                _limiteProdutosExibidos += 10; // Puxa mais 10 em tempo real sô!
                              });
                            },
                          ),
                        ),
                      );
                    }

                    final item = produtosDocs[index];
                    final dados = item.data() as Map<String, dynamic>;

                    String nome = dados['nome'] ?? 'Sem nome';
                    double preco = (dados['preco'] ?? 0.0).toDouble();
                    bool disponivel = dados['disponivel'] ?? true;
                    String descricao = dados['descricao'] ?? '';
                    String categoriaProd = dados['categoria_produto'] ?? 'Outros';

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selo bonitinho da seção do cardápio sô!
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE65100).withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  categoriaProd.toUpperCase(),
                                  style: const TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                descricao,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
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
                                    ).then((_) => _buscarLimiteDeProdutos());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
