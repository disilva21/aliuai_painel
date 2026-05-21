import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:html_editor_enhanced/html_editor.dart';

class PerfilStoreScreen extends StatefulWidget {
  final String lojaId; // ✨ Agora o parâmetro é obrigatório e garantido pela Dashboard

  const PerfilStoreScreen({super.key, required this.lojaId});

  @override
  State<PerfilStoreScreen> createState() => _PerfilStoreScreenState();
}

class _PerfilStoreScreenState extends State<PerfilStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // Controllers
  final _nomeController = TextEditingController();
  HtmlEditorController _descricaoEditorController = HtmlEditorController();
  final _enderecoController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _fixoController = TextEditingController();
  final _tempoEntregaController = TextEditingController();
  final _taxaEntregaController = TextEditingController();

  String? _estadoSelecionado;
  String? _cidadeSelecionada;

  List<String> _estados = [];
  List<Map<String, String>> _cidades = [];
  bool _carregandoCidades = false;

  // Estados de controle da tela
  bool _carregando = true;
  bool _salvando = false;
  bool _fazDelivery = true;
  bool _subindoFoto = false;
  String? _categoriaSelecionadaId;
  String _logoUrl = '';
  List<Map<String, String>> _categoriasLojas = [];
  String _descricaoInicial = '';
  @override
  void initState() {
    super.initState();
    _carregarDadosAtuais();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoEditorController.clear();
    _enderecoController.dispose();
    _whatsappController.dispose();
    _fixoController.dispose();
    _tempoEntregaController.dispose();
    super.dispose();
  }

  void _carregarEstados() {
    setState(() {
      _estados = ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'];
    });
  }

  Future<void> _buscarCidadesPorEstado(String uf) async {
    setState(() {
      _carregandoCidades = true;
      _cidades = [];
      _cidadeSelecionada = null; // Limpa a cidade anterior se mudar o estado
    });

    try {
      // Busca na coleção 'cidades' onde o campo 'uf' for igual ao estado selecionado
      final snapshot = await FirebaseFirestore.instance
          .collection('cidades')
          .where('uf', isEqualTo: uf)
          .orderBy('nome') // Garante que a lista vem de A a Z
          .get();

      List<Map<String, String>> listaCidades = [];

      for (var doc in snapshot.docs) {
        String idCidade = doc.id; // 🔥 Captura o ID real do documento no Firestore
        String nomeCidade = doc.data()['nome'] ?? '';
        if (nomeCidade.isNotEmpty) {
          listaCidades.add({'id': idCidade, 'nome': nomeCidade});
        }
      }

      setState(() {
        _cidades = listaCidades;
        _carregandoCidades = false;
      });
    } catch (e) {
      setState(() => _carregandoCidades = false);
      debugPrint('Erro ao buscar cidades no Firestore: $e');

      // Alerta visual amigável caso falte criar o Índice no Firestore
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar cidades. Verifique os índices do Firestore.'), backgroundColor: Colors.red));
    }
  }

  /// ✨ MÉTODO REFATORADO: Carrega os dados direto pelo ID do documento
  Future<void> _carregarDadosAtuais() async {
    try {
      // 1. Busca as categorias cadastradas no sistema
      final snapshotCategorias = await _firestore.collection('categorias').get();
      final List<Map<String, String>> listaTemporaria = [];

      for (var doc in snapshotCategorias.docs) {
        listaTemporaria.add({'id': doc.id, 'nome': doc.get('nome') ?? ''});
      }

      // 2. Busca o estabelecimento direto usando o ID do documento fornecido pela Dashboard
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      if (mounted) {
        // ✨ CORREÇÃO: O setState agora executa de forma síncrona perfeita
        setState(() async {
          _categoriasLojas = listaTemporaria;
          _carregarEstados();
          if (docLoja.exists) {
            final dados = docLoja.data() as Map<String, dynamic>;

            // Alimenta os inputs com os dados do documento encontrado
            _nomeController.text = dados['nome'] ?? '';
            _descricaoInicial = dados['descricao'] ?? '';
            _enderecoController.text = dados['endereco'] ?? '';
            _whatsappController.text = dados['telefone_whatsapp'] ?? '';
            _fixoController.text = dados['telefone_fixo'] ?? '';
            _tempoEntregaController.text = dados['tempo_entrega'] ?? '30-45 min';
            _fazDelivery = dados['is_delivery'] ?? true;
            _logoUrl = dados['logo_url'] ?? '';
            _taxaEntregaController.text = (dados['taxa_entrega'] != null) ? dados['taxa_entrega'].toString() : '';

            final snapshot = await FirebaseFirestore.instance.collection('cidades').doc('${dados['cidade_id']}').get();

            if (snapshot.exists) {
              _estadoSelecionado = snapshot.data()?['uf'] ?? '';

              _buscarCidadesPorEstado(_estadoSelecionado!);
              _cidadeSelecionada = snapshot.id; // 🔥 Captura o ID real do documento no Firestore
            }

            // Seleciona a categoria que o Admin definiu previamente
            final catIdSalva = dados['categoria_id'];
            if (catIdSalva != null && _categoriasLojas.any((element) => element['id'] == catIdSalva)) {
              _categoriaSelecionadaId = catIdSalva;
            } else if (_categoriasLojas.isNotEmpty) {
              _categoriaSelecionadaId = _categoriasLojas.first['id'];
            }
          }

          _carregando = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados do perfil: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// ✨ MÉTODO REFATORADO: Upload de foto otimizado para usar widget.lojaId
  Future<void> _escolherEEnviarFoto() async {
    // 1. Abre a janela nativa para selecionar o arquivo
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true, // Garante os bytes na Web
    );

    // 2. Valida se o arquivo e seus bytes estão prontos
    if (resultado != null && resultado.files.first.bytes != null) {
      setState(() => _subindoFoto = true);

      try {
        final arquivoBytes = resultado.files.first.bytes!;
        final nomeArquivo = resultado.files.first.name;
        final extensao = nomeArquivo.split('.').last;

        // 3. Define a referência usando o ID limpo da loja
        final ref = _storage.ref().child('logos_estabelecimentos/${widget.lojaId}.$extensao');

        // 4. Executa o upload em Bytes para Flutter Web
        UploadTask uploadTask = ref.putData(arquivoBytes, SettableMetadata(contentType: 'image/$extensao'));

        TaskSnapshot snapshot = await uploadTask;
        String urlPublica = await snapshot.ref.getDownloadURL();

        // 5. Atualiza o banco com o novo link da foto
        await _firestore.collection('estabelecimentos').doc(widget.lojaId).update({'logo_url': urlPublica});

        if (mounted) {
          setState(() {
            _logoUrl = urlPublica;
            _subindoFoto = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo atualizada com sucesso! 📸'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _subindoFoto = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// ✨ MÉTODO REFATORADO: Salvamento direto no documento limpo
  Future<void> _salvarDados() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final taxaTexto = _taxaEntregaController.text.trim().replaceAll(',', '.');
    final taxaDouble = double.tryParse(taxaTexto) ?? 0.0;
    String? htmlGerado = await _descricaoEditorController.getText();

    try {
      await _firestore.collection('estabelecimentos').doc(widget.lojaId).update({
        'nome': _nomeController.text.trim(),
        'descricao': htmlGerado,
        'endereco': _enderecoController.text.trim(),
        'telefone_whatsapp': _whatsappController.text.trim(),
        'telefone_fixo': _fixoController.text.trim(),
        'tempo_entrega': _tempoEntregaController.text.trim(),
        'is_delivery': _fazDelivery,
        'categoria_id': _categoriaSelecionadaId,
        'cidade_id': _cidadeSelecionada,
        'taxa_entrega': _fazDelivery ? taxaDouble : 0.0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado com sucesso! 🎉'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar alterações: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏪 Perfil do Estabelecimento',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              const Text('Mantenha as configurações, logo e contatos da sua loja atualizados para o aplicativo.', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // UPLOAD DO LOGO DA LOJA
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!, width: 2),
                                ),
                                child: ClipOval(
                                  child: _subindoFoto
                                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                                      : _logoUrl.isNotEmpty
                                      ? Builder(
                                          builder: (context) {
                                            final String viewId = 'logo-${_logoUrl.hashCode}';
                                            ui_web.platformViewRegistry.registerViewFactory(
                                              viewId,
                                              (int viewId) => html.ImageElement()
                                                ..src = _logoUrl
                                                ..style.width = '100%'
                                                ..style.height = '100%'
                                                ..style.objectFit = 'cover',
                                            );
                                            return HtmlElementView(viewType: viewId);
                                          },
                                        )
                                      : Icon(Icons.add_business, size: 45, color: Colors.grey[400]),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE65100)),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Alterar Logomarca (PNG/JPG)', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _subindoFoto ? null : _escolherEEnviarFoto,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ENTRADAS DE TEXTO DO FORMULÁRIO
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _nomeController,
                                decoration: InputDecoration(
                                  labelText: 'Nome da Loja',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) => val!.isEmpty ? 'O nome não pode ficar vazio.' : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: _categoriaSelecionadaId,
                                decoration: InputDecoration(
                                  labelText: 'Ramo / Categoria do App',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _categoriasLojas.map((cat) {
                                  return DropdownMenuItem<String>(value: cat['id'], child: Text(cat['nome']!));
                                }).toList(),
                                onChanged: (id) => setState(() => _categoriaSelecionadaId = id),
                              ),
                            ),
                          ],
                        ),

                        // TextFormField(
                        //   controller: _descricaoEditorController,
                        //   maxLines: 2,
                        //   decoration: InputDecoration(
                        //     labelText: 'Descrição / Slogan',
                        //     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        //   ),
                        // ),
                        const SizedBox(height: 24),

                        // SELETOR SWITCH DO DELIVERY
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _fazDelivery ? Colors.orange[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _fazDelivery ? const Color(0xFFE65100).withOpacity(0.3) : Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_fazDelivery ? Icons.delivery_dining : Icons.storefront, color: _fazDelivery ? const Color(0xFFE65100) : Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Realiza Entregas (Delivery)?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text(
                                        _fazDelivery ? 'Ativo: Os clientes poderão pedir para entregar.' : 'Inativo: Pedidos apenas para balcão.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(value: _fazDelivery, activeColor: const Color(0xFFE65100), onChanged: (val) => setState(() => _fazDelivery = val)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_fazDelivery)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _tempoEntregaController,
                                  decoration: InputDecoration(
                                    labelText: 'Tempo de Entrega (Ex: 30-45 min)',
                                    prefixIcon: const Icon(Icons.timer_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _taxaEntregaController,

                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Valor da Taxa de Entrega (R\$)',
                                    hintText: '0,00',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.monetization_on_rounded),
                                  ),
                                  validator: (value) {
                                    // Se faz entrega, o valor da taxa passa a ser obrigatório
                                    if (_fazDelivery && (value == null || value.trim().isEmpty)) {
                                      return 'Por favor, insira o valor da taxa de entrega';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            // COMBO 1: ESTADOS (UF)
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _estadoSelecionado,
                                decoration: const InputDecoration(labelText: 'Estado (UF)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map_outlined)),
                                items: _estados.map((uf) {
                                  return DropdownMenuItem(value: uf, child: Text(uf));
                                }).toList(),
                                onChanged: (novoEstado) {
                                  if (novoEstado != null) {
                                    setState(() {
                                      _estadoSelecionado = novoEstado;
                                    });
                                    _buscarCidadesPorEstado(novoEstado);
                                  }
                                },
                                validator: (value) => value == null ? 'Selecione o estado' : null,
                              ),
                            ),

                            const SizedBox(width: 16),

                            // COMBO 2: CIDADES (Alimentado pela collection 'cidades')
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _cidadeSelecionada, // É o ID armazenado
                                disabledHint: Text(_carregandoCidades ? 'Carregando cidades...' : 'Selecione o Estado primeiro'),
                                decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city_rounded)),
                                // Mapeia a lista de mapas para os itens do Dropdown
                                items: _cidades.isNotEmpty
                                    ? _cidades.map((cidade) {
                                        return DropdownMenuItem<String>(
                                          value: cidade['id'], // 🔥 O valor por trás do clique é o ID
                                          child: Text(cidade['nome'] ?? ''), // O que o lojista lê é o Nome
                                        );
                                      }).toList()
                                    : null,
                                onChanged: _cidades.isNotEmpty
                                    ? (novoIdCidade) {
                                        setState(() {
                                          _cidadeSelecionada = novoIdCidade; // 🔥 Salva o ID selecionado no estado da tela
                                        });
                                      }
                                    : null,
                                validator: (value) => value == null ? 'Selecione a cidade' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _enderecoController,
                          decoration: InputDecoration(
                            labelText: 'Endereço Físico',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) => val!.isEmpty ? 'Informe o endereço.' : null,
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _whatsappController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'WhatsApp (com DDD - Ex: 031987654321)',
                                  prefixIcon: const Icon(Icons.phone_android, color: Colors.green),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) => val!.isEmpty ? 'O WhatsApp é obrigatório.' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _fixoController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Telefone Fixo (Opcional - Ex: 031987654321)',
                                  prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Text(
                          '* Utilize o campo abaixo para informar a descrição da loja, horários de atendimento, ou outras informações importantes para os clientes. Use as ferramentas de formatação para destacar detalhes como dias de funcionamento.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: HtmlEditor(
                            controller: _descricaoEditorController,
                            htmlEditorOptions: HtmlEditorOptions(
                              hint: "Ex: <b>Dias de atendimento:</b> Quarta a Domingo...",
                              initialText: _descricaoInicial, // Injeta o texto do Firestore
                              shouldEnsureVisible: true,
                              autoAdjustHeight: true,
                            ),
                            htmlToolbarOptions: HtmlToolbarOptions(
                              toolbarPosition: ToolbarPosition.aboveEditor, // Barra fixa no topo
                              toolbarType: ToolbarType.nativeScrollable, // Rolagem suave dos botões
                              // Lista limpa e atualizada de ferramentas para o lojista usar
                              defaultToolbarButtons: [
                                const FontSettingButtons(fontSize: true), // Tamanho da letra
                                const FontButtons(bold: true, italic: true, underline: true, clearAll: true), // Formatações básicas
                                const ColorButtons(foregroundColor: true), // Cores do texto
                                const ListButtons(ul: true, ol: true), // Marcadores de listas (ótimo para horários)
                                const ParagraphButtons(alignLeft: true, alignCenter: true, alignRight: true),
                              ],
                            ),

                            // Outras opções de tamanho do container interno
                            otherOptions: const OtherOptions(height: 200),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // BOTÃO SALVAR ALTERAÇÕES
                        SizedBox(
                          height: 50,
                          width: 200,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: _salvando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                            label: Text(_salvando ? 'Salvando...' : 'Salvar Alterações', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _salvando ? null : _salvarDados,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
