import 'package:aliuai_painel/admin/icon_widget.dart';
import 'package:aliuai_painel/services/cargas.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GerenciamentoCategoriasPage extends StatefulWidget {
  const GerenciamentoCategoriasPage({super.key});

  @override
  State<GerenciamentoCategoriasPage> createState() => _GerenciamentoCategoriasPageState();
}

class _GerenciamentoCategoriasPageState extends State<GerenciamentoCategoriasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('⚙️ Configuração de Categorias - AliUai'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_view), text: '1. Categorias Principais (Grid)'),
              Tab(icon: Icon(Icons.shopping_bag), text: '2. Categorias de Produtos'),
            ],
          ),
        ),
        body: TabBarView(children: [_abaCategoriasPrincipais(), _abaCategoriasProdutos()]),
      ),
    );
  }

  void _abrirSeletorDeIcone() {}

  // =========================================================================
  // 🏢 ABA 1: LISTAGEM E EDIÇÃO DAS CATEGORIAS PRINCIPAIS (GRID DO APP)
  // =========================================================================
  Widget _abaCategoriasPrincipais() {
    // CargaDeCategorias.fazerCargaDeCategorias(); // 🚀 Chama a função de carga de categorias no Firestore

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('categorias').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final cat = docs[index].data() as Map<String, dynamic>;
            final idDoc = docs[index].id;

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(cat['cor'].toString().replaceFirst('#', '0xff'))),
                  child: Icon(IconData(int.parse(cat['icone']), fontFamily: 'MaterialIcons'), color: Colors.white),
                ),
                title: Text(cat['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ID: $idDoc Ordem: ${cat['ordem']}'), Text('Ordem: ${cat['ordem']}')]),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _modalEditarCategoriaPrincipal(idDoc, cat),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 📦 ABA 2: LISTAGEM E VINCULO DAS CATEGORIAS DE PRODUTOS
  // =========================================================================
  Widget _abaCategoriasProdutos() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('categoria_produto').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final catProd = docs[index].data() as Map<String, dynamic>;
            final idDoc = docs[index].id;
            List<dynamic> permitidos = catProd['estabelecimentos_permitidos'] ?? [];

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(catProd['nome'] ?? 'Sem nome', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Icon(Icons.circle, color: (catProd['ativo'] ?? true) ? Colors.green : Colors.red, size: 12),
                            const SizedBox(width: 4),
                            Text((catProd['ativo'] ?? true) ? 'Ativo' : 'Inativo'),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.settings, color: Colors.orange),
                              onPressed: () => _modalEditarCategoriaProduto(idDoc, catProd),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text('Slug: ${catProd['slug'] ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('Vínculos (Categorias do Grid):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    // 🚀 Mostra as tags de onde essa categoria de produto aparece uai!
                    Wrap(
                      spacing: 6,
                      children: permitidos.isEmpty
                          ? [Text('Nenhum vínculo. Não vai aparecer no app sô!', style: TextStyle(color: Colors.red[700], fontSize: 12))]
                          : permitidos
                                .map(
                                  (slug) => Chip(
                                    label: Text(slug.toString(), style: const TextStyle(fontSize: 11)),
                                    backgroundColor: Colors.blue[50],
                                  ),
                                )
                                .toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 🛠️ MODAL DE EDIÇÃO: CATEGORIA PRINCIPAL
  // =========================================================================
  void _modalEditarCategoriaPrincipal(String idDoc, Map<String, dynamic> dados) {
    final nomeController = TextEditingController(text: dados['nome']);
    // final slugController = TextEditingController(text: dados['slug']);
    final iconeController = TextEditingController(text: dados['icone']);
    final corController = TextEditingController(text: dados['cor']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Categoria: ${dados['nome']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome da Categoria'),
            ),
            // TextField(
            //   controller: slugController,
            //   decoration: const InputDecoration(labelText: 'Slug (ID único)'),
            // ),
            TextField(
              controller: iconeController,
              decoration: const InputDecoration(labelText: 'Código do Ícone (ex: 58711)'),
            ),
            ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // Permite que a modal suba acima do teclado
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return SeletorIconesModal(
                      onIconeSelecionado: (codePoint, nomeIcone) {
                        // 🎯 O que fazer quando o ícone for selecionado sô:
                        print('Código para o Firestore: $codePoint');
                        print('Nome do ícone: $nomeIcone');

                        setState(() {
                          iconeController.text = codePoint.toString();
                        });

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ícone $nomeIcone ($codePoint) selecionado, uai!')));
                      },
                    );
                  },
                );
              },
              child: const Text('Selecionar Ícone'),
            ),
            TextField(
              controller: corController,
              decoration: const InputDecoration(labelText: 'Cor HEX (ex: #FF9800)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('categorias').doc(idDoc).update({
                'nome': nomeController.text,
                // 'slug': slugController.text,
                'icone': iconeController.text,
                'cor': corController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🛠️ MODAL DE EDIÇÃO: CATEGORIA PRODUTO (CORRIGIDO E TESTADO SÔ!)
  // =========================================================================
  void _modalEditarCategoriaProduto(String idDoc, Map<String, dynamic> dados) {
    final nomeController = TextEditingController(text: dados['nome']);
    bool ativo = dados['ativo'] ?? true;

    // 🚀 Cria uma lista limpa contendo apenas as Strings dos slugs permitidos
    List<String> temporarioPermitidos = List<String>.from((dados['estabelecimentos_permitidos'] as List? ?? []).map((e) => e.toString()));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Configurar: ${dados['nome']}'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID do Produto (Fixo): $idDoc',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome da Categoria do Produto'),
                    ),
                    SwitchListTile(title: const Text('Categoria Ativa?'), value: ativo, onChanged: (val) => setModalState(() => ativo = val)),
                    const Divider(),
                    const Text('Marque onde essa categoria pode aparecer uai:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    FutureBuilder<QuerySnapshot>(
                      future: _firestore.collection('categorias').get(),
                      builder: (context, catSnapshot) {
                        if (!catSnapshot.hasData) return const LinearProgressIndicator();

                        return Column(
                          children: catSnapshot.data!.docs.map((catDoc) {
                            final catData = catDoc.data() as Map<String, dynamic>;
                            final String catSlug = catDoc.id; // 🔑 O ID único do documento (ex: cat_mercados)
                            final catNome = catData['nome'] ?? '';

                            // 🎯 AQUI TAVA O ERRO SÔ: Checa se ESSE slug específico está na lista
                            final bool jaMarcado = temporarioPermitidos.contains(catSlug);

                            return CheckboxListTile(
                              key: ValueKey(catSlug), // Força o Flutter a diferenciar as linhas uai!
                              title: Text(catNome),
                              subtitle: Text('ID fixo: $catSlug', style: const TextStyle(fontSize: 11)),
                              value: jaMarcado,
                              onChanged: (bool? marcado) {
                                // 🛠️ Atualiza o estado interno do Modal na marra sô!
                                setModalState(() {
                                  if (marcado == true) {
                                    if (!temporarioPermitidos.contains(catSlug)) {
                                      temporarioPermitidos.add(catSlug);
                                    }
                                  } else {
                                    temporarioPermitidos.remove(catSlug);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  await _firestore.collection('categoria_produto').doc(idDoc).update({
                    'nome': nomeController.text,
                    'ativo': ativo,
                    'estabelecimentos_permitidos': temporarioPermitidos, // Salva o array certinho
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Salvar Configuração'),
              ),
            ],
          );
        },
      ),
    );
  }
}
