import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class PainelUtilidadesPage extends StatefulWidget {
  const PainelUtilidadesPage({super.key});

  @override
  State<PainelUtilidadesPage> createState() => _PainelUtilidadesPageState();
}

class _PainelUtilidadesPageState extends State<PainelUtilidadesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _salvando = false;

  final _formKeyTelefone = GlobalKey<FormState>();
  final _formKeyOnibus = GlobalKey<FormState>();

  // Controladores dos Inputs
  final _tituloController = TextEditingController();
  final _subtituloController = TextEditingController();
  final _detalhesController = TextEditingController();
  final _ordemController = TextEditingController(); // 🔢 Controla o peso da ordenação das duas abas sô!

  // Controlador exclusivo do Editor HTML sô!
  final HtmlEditorController _htmlEditorController = HtmlEditorController();

  String? _urlImagemEvento;

  // VARIÁVEIS PARA A CIDADE SELECIONADA
  String? _idCidadeSelecionada;
  String? _nomeCidadeSelecionada;

  // Controle de estado para saber se estamos editando um registro sô!
  String? _idDocSendoEditado;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Limpa os campos se o lojista pular de aba enquanto edita sô!
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _limparCampos();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tituloController.dispose();
    _subtituloController.dispose();
    _detalhesController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  // Função unificada para Salvar (Cadastrar ou Atualizar) no Firebase
  Future<void> _salvarUtilidade(String tipo, GlobalKey<FormState> formKeyDaAba) async {
    if (!formKeyDaAba.currentState!.validate()) return;

    if (_idCidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma cidade primeiro, sô!'), backgroundColor: Colors.amber));
      return;
    }

    setState(() => _salvando = true);

    try {
      final textoHtml = await _htmlEditorController.getText();
      _detalhesController.text = textoHtml;

      // 🔢 Tratamento da Ordem (Agora roda para telefone E ônibus sô!):
      int pesoOrdem = 99;
      if (_ordemController.text.trim().isNotEmpty) {
        pesoOrdem = int.tryParse(_ordemController.text.trim()) ?? 99;
      }

      final dados = {
        'tipo': tipo,
        'cidade_id': _idCidadeSelecionada,
        'cidade_nome': _nomeCidadeSelecionada,
        'titulo': _tituloController.text.trim(),
        'subtitulo': _subtituloController.text.trim(),
        'detalhes': _detalhesController.text.trim(),
        'imagem': tipo == 'evento' ? (_urlImagemEvento ?? '') : '',
        'ordem': pesoOrdem, // 💾 Salvando o peso da fila bonito!
        if (_idDocSendoEditado == null) 'criado_em': FieldValue.serverTimestamp(),
        'atualizado_em': FieldValue.serverTimestamp(),
      };

      if (_idDocSendoEditado == null) {
        // ➕ MODO CADASTRO
        await FirebaseFirestore.instance.collection('utilidades_locais').add(dados);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conteúdo publicado com sucesso! 🎉'), backgroundColor: Colors.green));
        }
      } else {
        // 📝 MODO EDIÇÃO
        await FirebaseFirestore.instance.collection('utilidades_locais').doc(_idDocSendoEditado).update(dados);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro atualizado com sucesso! 📝'), backgroundColor: Colors.blue));
        }
      }

      _limparCampos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limparCampos() {
    setState(() {
      _tituloController.clear();
      _subtituloController.clear();
      _detalhesController.clear();
      _ordemController.clear();
      _htmlEditorController.clear();
      _urlImagemEvento = null;
      _idDocSendoEditado = null;
      _idCidadeSelecionada = null;
      _nomeCidadeSelecionada = null;
    });
  }

  // Preenche o formulário com o item selecionado na direita para edição sô
  void _prepararEdicao(String docId, Map<String, dynamic> item) {
    setState(() {
      _idDocSendoEditado = docId;
      _idCidadeSelecionada = item['cidade_id'];
      _nomeCidadeSelecionada = item['cidade_nome'];
      _tituloController.text = item['titulo'] ?? '';
      _subtituloController.text = item['subtitulo'] ?? '';
      _detalhesController.text = item['detalhes'] ?? '';
      // Se a ordem for 99 (padrão antigo ou vazio), limpamos o campo para o lojista sô!
      _ordemController.text = item['ordem'] != null && item['ordem'] != 99 ? item['ordem'].toString() : '';

      _htmlEditorController.setText(item['detalhes'] ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Gerenciar Utilidades Locais', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE65100),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE65100),
          tabs: const [
            Tab(icon: Icon(Icons.phone), text: 'Telefones Úteis'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Ônibus / Horários'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirFormularioEListagem(formKey: _formKeyTelefone, tipo: 'telefone', labelTitulo: 'Nome do Local', labelSubtitulo: 'Número do Telefone', labelDetalhes: 'Observações'),
          _construirFormularioEListagem(formKey: _formKeyOnibus, tipo: 'onibus', labelTitulo: 'Nome da Linha', labelSubtitulo: 'Itinerário / Trajeto', labelDetalhes: 'Horários da Linha'),
        ],
      ),
    );
  }

  Widget _construirFormularioEListagem({
    required GlobalKey<FormState> formKey,
    required String tipo,
    required String labelTitulo,
    required String labelSubtitulo,
    required String labelDetalhes,
    bool mostrarUpload = false,
  }) {
    return Row(
      children: [
        // LADO ESQUERDO: Formulário de Cadastro / Edição (40%)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_idDocSendoEditado == null ? 'Adicionar Novo Registro' : 'Editar Registro Selecionado 📝', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // COMBOBOX CIDADES
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('cidades').orderBy('nome').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator(color: Color(0xFFE65100));
                        }

                        var cidadesDocs = snapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          dropdownColor: Colors.grey[100]!,
                          value: _idCidadeSelecionada,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Selecione a Cidade',
                            labelStyle: const TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE65100))),
                            filled: true,
                            fillColor: const Color(0xFFFFFFFF),
                          ),
                          items: cidadesDocs.map((doc) {
                            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(color: Colors.black)),
                            );
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

                    // 🚀 O PULO DO GATO SÔ: Agora o input de ordem brota tanto para telefone quanto para onibus!
                    _construirInput(controller: _ordemController, label: 'Ordem de Exibição (Ex: 1 para o topo, 2, 3...)', isNumeric: true),
                    const SizedBox(height: 16),

                    _construirInput(controller: _detalhesController, label: labelDetalhes, maxLines: 4, htmlController: _htmlEditorController),
                    const SizedBox(height: 16),

                    if (mostrarUpload) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _urlImagemEvento = "https://placehold.co/150";
                          });
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Subir Banner do Evento'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // BOTÕES DE AÇÃO
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _idDocSendoEditado == null ? const Color(0xFFE65100) : Colors.blue[800]),
                            onPressed: _salvando ? null : () => _salvarUtilidade(tipo, formKey),
                            child: _salvando
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(_idDocSendoEditado == null ? 'Publicar no App' : 'Salvar Alterações', style: const TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),
                        if (_idDocSendoEditado != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
                              onPressed: _limparCampos,
                              child: const Text('Cancelar Edição', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // LADO DIREITO: Listagem Filtrada e Ordenada (60%)
        Expanded(
          flex: 6,
          child: StreamBuilder<QuerySnapshot>(
            // 🚀 Ambas as abas agora escutam respeitando a ordem do menor peso pro maior sô!
            stream: FirebaseFirestore.instance.collection('utilidades_locais').where('tipo', isEqualTo: tipo).orderBy('ordem').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print("Erro na consulta do Firebase sô: ${snapshot.error}");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Erro ao carregar ou criando índice no banco sô! Detalhe: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
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
                  final itemDoc = itens[index];
                  final item = itemDoc.data() as Map<String, dynamic>;
                  final docId = itemDoc.id;
                  final cidadeNome = item['cidade_nome'] ?? 'Geral';
                  final int exibeOrdem = item['ordem'] ?? 99;

                  final bool sendoEditadoEsqueleto = _idDocSendoEditado == docId;

                  return Card(
                    color: const Color(0xFFFFFFFF),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: sendoEditadoEsqueleto
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.blue, width: 2),
                          )
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE65100).withOpacity(0.1),
                        child: Text(
                          '#$exibeOrdem',
                          style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        item['titulo'] ?? '',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cidade: $cidadeNome\n${item['subtitulo'] ?? ''}', style: const TextStyle(color: Colors.black87)),
                          Html(
                            data: item['detalhes'],
                            style: {
                              "body": Style(fontSize: FontSize(14.0), color: Colors.grey[800], fontFamily: 'Poppins', lineHeight: LineHeight.normal),
                              "strong": Style(color: const Color(0xFFE65100)),
                            },
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 26),
                            tooltip: 'Editar Registro',
                            onPressed: () => _prepararEdicao(docId, item),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            tooltip: 'Excluir Registro',
                            onPressed: () {
                              if (_idDocSendoEditado == docId) _limparCampos();
                              FirebaseFirestore.instance.collection('utilidades_locais').doc(docId).delete();
                            },
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
    );
  }

  // 🛠️ MÉTODO DE INPUT LIVRE SÔ!
  Widget _construirInput({required TextEditingController controller, required String label, int maxLines = 1, HtmlEditorController? htmlController, bool isNumeric = false}) {
    if (htmlController != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HtmlEditor(
              controller: htmlController,
              htmlEditorOptions: HtmlEditorOptions(hint: "informe os detalhes", initialText: controller.text, shouldEnsureVisible: true, autoAdjustHeight: true),
              htmlToolbarOptions: const HtmlToolbarOptions(
                toolbarPosition: ToolbarPosition.aboveEditor,
                toolbarType: ToolbarType.nativeScrollable,
                defaultToolbarButtons: [
                  ColorButtons(foregroundColor: true),
                  FontSettingButtons(fontSize: true),
                  FontButtons(bold: true, italic: true, underline: true, clearAll: true),
                  ListButtons(ul: true, ol: true),
                  ParagraphButtons(alignLeft: true, alignCenter: true, alignRight: true),
                ],
              ),
              otherOptions: const OtherOptions(height: 200),
            ),
          ),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE65100))),
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
      ),
      validator: (value) {
        if (label.contains('Ordem')) return null; // Ordem opcional sô!
        return value == null || value.isEmpty ? 'Campo obrigatório' : null;
      },
    );
  }
}
