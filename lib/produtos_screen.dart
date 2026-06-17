import 'package:aliuai_painel/widget/dialog_panfleto_widget.dart';
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

  // Variável que armazena a categoria/nicho pai da loja logada sô!
  String categoriaLoja = 'cat_utilidades';
  String? nomeLoja;

  @override
  void initState() {
    super.initState();
    _inicializarDadosDaTela();
  }

  /// 🧠 Orquestra as buscas de forma síncrona para um dado não atropelar o outro sô!
  Future<void> _inicializarDadosDaTela() async {
    await _buscarLimiteDeProdutos(); // 1. Puxa os dados da loja e atualiza o estado primeiro!
    await _carregarCategoriasDoNichoDaLoja(); // 2. Com a categoriaLoja real, busca o combo do topo!
  }

  /// 🛠️ MÉTODO REFATORADO: Busca apenas o catálogo que faz sentido para o ramo dessa loja sô!
  Future<void> _carregarCategoriasDoNichoDaLoja() async {
    try {
      setState(() => _carregandoCategorias = true);

      // 📡 Faz a busca filtrada trazendo só o que o array 'estabelecimentos_permitidos' liberar!
      final snapshot = await _firestore.collection('categoria_produto').where('estabelecimentos_permitidos', arrayContains: categoriaLoja).where('ativo', isEqualTo: true).get();

      final List<Map<String, dynamic>> carregadas = snapshot.docs.map((doc) {
        final dados = doc.data();
        return {
          'id': dados['slug'] ?? doc.id, // 🔥 Usa o SLUG em minúsculo para bater com os produtos!
          'nome': dados['nome'].toString(),
        };
      }).toList();

      // Deixa a listinha em ordem alfabética sô!
      carregadas.sort((a, b) => a['nome'].compareTo(b['nome']));

      if (mounted) {
        setState(() {
          _categoriasFiltroLista = carregadas;
          _carregandoCategorias = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias no filtro por nicho sô: $e');
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

  /// 🛠️ CORRIGIDO: Agora seta a categoriaLoja de forma segura forçando a reconstrução da árvore sô!
  Future<void> _buscarLimiteDeProdutos() async {
    try {
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      int limiteRecuperado = 0;
      String categoriaRecuperada = 'cat_utilidades';

      if (docLoja.exists) {
        limiteRecuperado = docLoja.data()?['limite_produtos'] ?? 0;
        // 🔥 Garante que vai ler o campo correto do banco (categoria_id ou categoria_estabelecimento sô)
        categoriaRecuperada = docLoja.data()?['categoria_id'] ?? docLoja.data()?['categoria_estabelecimento'] ?? 'cat_utilidades';
        nomeLoja = docLoja.data()?['nome'];
      }

      final snapshotContagem = await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').count().get();
      int totalProdutos = snapshotContagem.count ?? 0;

      if (mounted) {
        setState(() {
          _limiteProdutosPlano = limiteRecuperado;
          _produtosCadastradosTotal = totalProdutos;
          categoriaLoja = categoriaRecuperada; // 🔥 Agora sim reconstrói o StreamBuilder com o ID certo!
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar limites de produtos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lojaId == null) return const Center(child: Text('Loja não identificada.'));

    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelularGeral = larguraTela < 800;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de Cabeçalho Responsiva
          LayoutBuilder(
            builder: (context, constraints) {
              final bool ehCelularTop = constraints.maxWidth < 800;

              final Widget blocoTextos = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📦 Gerenciador Produtos',
                    style: TextStyle(fontSize: ehCelularTop ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text('Ative ou pause seus itens cadastrados em tempo real.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              );

              final Widget botaoNovo = SizedBox(
                width: ehCelularTop ? double.infinity : null,
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
                      builder: (context) => CadastroProdutoModal(lojaId: widget.lojaId!, categoriaLoja: categoriaLoja), // 🔥 Atualizado parâmetro para categoriaLoja sô!
                    ).then((_) => _buscarLimiteDeProdutos());
                  },
                ),
              );

              if (ehCelularTop) {
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

          // Seletor de Categorias Responsivo sô
          _carregandoCategorias
              ? const LinearProgressIndicator(color: Color(0xFFE65100))
              : Container(
                  width: ehCelularGeral ? double.infinity : 300,
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
                          _limiteProdutosExibidos = 10;
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
                Query queryBase = _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').orderBy('nome');
                if (_categoriaFiltroId != null) {
                  queryBase = queryBase.where('categoria_id', isEqualTo: _categoriaFiltroId);
                }
                return queryBase.limit(_limiteProdutosExibidos).snapshots();
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return const Center(child: Text('Erro ao carregar os dados Produtos Screen.'));
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

                _temMaisProdutos = produtosDocs.length == _limiteProdutosExibidos;

                return ListView.builder(
                  itemCount: produtosDocs.length + (_temMaisProdutos ? 1 : 0),
                  itemBuilder: (context, index) {
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
                                _limiteProdutosExibidos += 10;
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
                    String codigo = dados['codigo'] ?? '';
                    String categoriaProd = dados['categoria_produto'] ?? 'Outros';

                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ehCelularGeral
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFE65100).withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      categoriaProd.toUpperCase(),
                                      style: const TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (descricao.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      descricao,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Divider(color: Color(0xFFF5F5F5)),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'R\$ ${preco.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100)),
                                      ),
                                      Row(
                                        children: [
                                          const Text('Gerar Panfleto', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Padding(
                                            padding: const EdgeInsets.only(right: 20),
                                            child: IconButton(
                                              icon: const Icon(Icons.campaign_rounded, color: Colors.purple, size: 24),
                                              tooltip: 'Gerar Panfleto de Oferta 📸',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => DialogPanfleto(
                                                    produto: dados, // 👈 repassa o Map dos dados do produto do Firebase sô
                                                    nomeLoja: nomeLoja ?? 'Nossa Loja',
                                                    idLoja: widget.lojaId!,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),

                                          const Text('Disponível', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Switch(value: disponivel, activeColor: const Color(0xFFE65100), onChanged: (val) => _alternarDisponibilidade(item.id, disponivel)),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                            child: IconButton(
                                              icon: const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 24),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => CadastroProdutoModal(
                                                    lojaId: widget.lojaId!,
                                                    produtoExistente: item.data() as Map<String, dynamic>?,
                                                    idProduto: item.id,
                                                    categoriaLoja: categoriaLoja, // 🔥 Parâmetro ajustado sô!
                                                  ),
                                                ).then((_) => _buscarLimiteDeProdutos());
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 6),
                                        Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFFE65100).withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                categoriaProd.toUpperCase(),
                                                style: const TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            // const SizedBox(width: 12),
                                            // Expanded(
                                            //   child: Text(
                                            //     descricao,
                                            //     maxLines: 1,
                                            //     overflow: TextOverflow.ellipsis,
                                            //     style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 305,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text('Gerar Panfleto', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        IconButton(
                                          icon: const Icon(Icons.campaign_rounded, color: Colors.purple, size: 24),
                                          tooltip: 'Gerar Panfleto de Oferta 📸',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => DialogPanfleto(
                                                produto: dados, // 👈 repassa o Map dos dados do produto do Firebase sô
                                                nomeLoja: nomeLoja ?? 'Nossa Loja',
                                                idLoja: widget.lojaId!,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 24),
                                        const Text('Disponível', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        SizedBox(
                                          child: Switch(value: disponivel, activeColor: const Color(0xFFE65100), onChanged: (val) => _alternarDisponibilidade(item.id, disponivel)),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                          child: IconButton(
                                            icon: const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 24),
                                            tooltip: 'Editar Produto',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => CadastroProdutoModal(
                                                  lojaId: widget.lojaId!,
                                                  produtoExistente: item.data() as Map<String, dynamic>?,
                                                  idProduto: item.id,
                                                  categoriaLoja: categoriaLoja, // 🔥 Parâmetro ajustado sô!
                                                ),
                                              ).then((_) => _buscarLimiteDeProdutos());
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
