import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html_editor_enhanced/html_editor.dart'; // 🔥 Import do editor rico sô!

class PainelUtilidadesPage extends StatefulWidget {
  const PainelUtilidadesPage({super.key});

  @override
  State<PainelUtilidadesPage> createState() => _PainelUtilidadesPageState();
}

class _PainelUtilidadesPageState extends State<PainelUtilidadesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  // Controladores dos Inputs
  final _tituloController = TextEditingController();
  final _subtituloController = TextEditingController();
  final _detalhesController = TextEditingController();

  // 🔥 Controlador exclusivo do Editor HTML sô!
  final HtmlEditorController _htmlEditorController = HtmlEditorController();

  String? _urlImagemEvento;

  // 🔴 VARIÁVEIS PARA A CIDADE SELECIONADA
  String? _idCidadeSelecionada;
  String? _nomeCidadeSelecionada;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tituloController.dispose();
    _subtituloController.dispose();
    _detalhesController.dispose();
    super.dispose();
  }

  // Função para salvar no Firebase incluindo a Cidade
  Future<void> _salvarUtilidade(String tipo) async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma cidade primeiro, sô!'), backgroundColor: Colors.amber));
      return;
    }

    setState(() => _salvando = true);

    try {
      // 🔥 O PULO DO GATO SÊNIOR: Antes de salvar, extraímos o texto com as tags HTML do editor!
      final textoHtml = await _htmlEditorController.getText();
      _detalhesController.text = textoHtml;

      final dados = {
        'tipo': tipo,
        'cidade_id': _idCidadeSelecionada, // 🔴 SALVA O ID DA CIDADE
        'cidade_nome': _nomeCidadeSelecionada, // Facilita se precisar exibir o nome direto
        'titulo': _tituloController.text.trim(),
        'subtitulo': _subtituloController.text.trim(),
        'detalhes': _detalhesController.text.trim(), // Salva o HTML purinho sô!
        'imagem': tipo == 'evento' ? (_urlImagemEvento ?? '') : '',
        'criado_em': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('utilidades_locais').add(dados);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conteúdo publicado com sucesso!'), backgroundColor: Colors.green));
        _limparCampos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limparCampos() {
    _tituloController.clear();
    _subtituloController.clear();
    _detalhesController.clear();
    _htmlEditorController.clear(); // 🔥 Limpa o editor de texto rico também sô!
    _urlImagemEvento = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E26),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        title: const Text(
          'Gerenciar Utilidades Locais',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE65100),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE65100),
          tabs: const [
            Tab(icon: Icon(Icons.phone), text: 'Telefones Úteis'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Ônibus / Horários'),
            Tab(icon: Icon(Icons.event), text: 'Eventos da Cidade'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirFormularioEListagem(tipo: 'telefone', labelTitulo: 'Nome do Local', labelSubtitulo: 'Número do Telefone', labelDetalhes: 'Observações'),
          _construirFormularioEListagem(tipo: 'onibus', labelTitulo: 'Nome da Linha', labelSubtitulo: 'Itinerário / Trajeto', labelDetalhes: 'Horários da Linha'),
          _construirFormularioEListagem(tipo: 'evento', labelTitulo: 'Nome do Evento', labelSubtitulo: 'Data e Local', labelDetalhes: 'Descrição do Evento', mostrarUpload: true),
        ],
      ),
    );
  }

  Widget _construirFormularioEListagem({required String tipo, required String labelTitulo, required String labelSubtitulo, required String labelDetalhes, bool mostrarUpload = false}) {
    return Row(
      children: [
        // LADO ESQUERDO: Formulário de Cadastro (40%)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adicionar Novo Registro',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // 🔴 COMBOBOX (DROPDOWN) BUSCANDO CIDADES DO FIRESTORE
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('cidades').orderBy('nome').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator(color: Color(0xFFE65100));
                        }

                        var cidadesDocs = snapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF2D2D3A),
                          value: _idCidadeSelecionada,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Selecione a Cidade',
                            labelStyle: const TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE65100))),
                            filled: true,
                            fillColor: const Color(0xFF2D2D3A),
                          ),
                          items: cidadesDocs.map((doc) {
                            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(value: doc.id, child: Text(data['nome'] ?? 'Sem nome'));
                          }).toList(),
                          onChanged: (novoId) {
                            setState(() {
                              _idCidadeSelecionada = novoId;
                              var docSelecionado = cidadesDocs.firstWhere((d) => d.id == novoId);
                              _nomeCidadeSelecionada = (docSelecionado.data() as Map<String, dynamic>)['nome'];
                            });
                          },
                          validator: (value) => value == null ? 'Selecione uma cidade' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    _construirInput(controller: _tituloController, label: labelTitulo),
                    const SizedBox(height: 16),
                    _construirInput(controller: _subtituloController, label: labelSubtitulo),
                    const SizedBox(height: 16),

                    // 🔥 Passamos o htmlController aqui! Quando ele vai, o método ativa o modo Rich Text sô!
                    _construirInput(controller: _detalhesController, label: labelDetalhes, maxLines: 4, htmlController: _htmlEditorController),
                    const SizedBox(height: 16),

                    if (mostrarUpload) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _urlImagemEvento = "https://placehold.co/150"; // Trocado a URL morta sô!
                          });
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Subir Banner do Evento'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                        onPressed: _salvando ? null : () => _salvarUtilidade(tipo),
                        child: _salvando ? const CircularProgressIndicator(color: Colors.white) : const Text('Publicar no App', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // LADO DIREITO: Listagem Filtrada por Tipo (60%)
        Expanded(
          flex: 6,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('utilidades_locais').where('tipo', isEqualTo: tipo).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Nenhum registro cadastrado nesta categoria.', style: TextStyle(color: Colors.grey)),
                );
              }

              final itens = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: itens.length,
                itemBuilder: (context, index) {
                  final item = itens[index].data() as Map<String, dynamic>;
                  final docId = itens[index].id;
                  final cidadeNome = item['cidade_nome'] ?? 'Geral';

                  return Card(
                    color: const Color(0xFF2D2D3A),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        tipo == 'telefone'
                            ? Icons.phone_in_talk
                            : tipo == 'onibus'
                            ? Icons.directions_bus_filled
                            : Icons.festival,
                        color: const Color(0xFFE65100),
                      ),
                      title: Text(
                        item['titulo'] ?? '',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Cidade: $cidadeNome\n${item['subtitulo'] ?? ''}\n${item['detalhes'] ?? ''}', style: TextStyle(color: Colors.grey[400])),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance.collection('utilidades_locais').doc(docId).delete();
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 🛠️ MÉTODO DE INPUT ATUALIZADO E FLEXÍVEL SÔ!
  Widget _construirInput({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    HtmlEditorController? htmlController, // 🔥 Adicionado o controller opcional
  }) {
    // Se passarmos o htmlController, ele monta o editor rico sô!
    if (htmlController != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D3A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: HtmlEditor(
              controller: htmlController,
              htmlEditorOptions: HtmlEditorOptions(
                hint: "Digite os detalhes aqui sô...",
                initialText: controller.text,
                darkMode: true, // Combina perfeitamente com o tema escuro do painel sô!
              ),
              htmlToolbarOptions: const HtmlToolbarOptions(
                toolbarPosition: ToolbarPosition.aboveEditor,
                toolbarType: ToolbarType.nativeScrollable,
                buttonColor: Colors.white,
                dropdownBackgroundColor: Color(0xFF2D2D3A),
                // ✂️ Cortamos a linha do imagePopoverToolbarOptions daqui sô!
                defaultToolbarButtons: [
                  FontButtons(bold: true, italic: true, underline: true, clearAll: true),
                  ParagraphButtons(lineHeight: false, caseConverter: false, textDirection: false),
                  ListButtons(ul: true, ol: true),
                  // 🔥 Explicitamente deixamos de fora os "InsertButtons" (que trazem link de imagem/vídeo)
                ],
              ),
              otherOptions: const OtherOptions(height: 200),
            ),
          ),
        ],
      );
    }

    // Caso contrário, continua renderizando o input padrão escuro sô
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE65100))),
        filled: true,
        fillColor: const Color(0xFF2D2D3A),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}
