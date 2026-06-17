import 'package:aliuai_painel/widget/qrcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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
  final HtmlEditorController _descricaoEditorController = HtmlEditorController();
  final _enderecoController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _fixoController = TextEditingController();
  final _tempoEntregaController = TextEditingController();
  final _taxaEntregaController = TextEditingController();
  final _nomeContatoCtrl = TextEditingController();

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
    _nomeContatoCtrl.dispose();
    _whatsappController.dispose();
    _fixoController.dispose();
    _tempoEntregaController.dispose();
    _taxaEntregaController.dispose();
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
      final snapshot = await FirebaseFirestore.instance
          .collection('cidades')
          .where('uf', isEqualTo: uf)
          .orderBy('nome') // Garante que a lista vem de A a Z
          .get();

      List<Map<String, String>> listaCidades = [];

      for (var doc in snapshot.docs) {
        String idCidade = doc.id;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar cidades. Verifique os índices do Firestore.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _carregarDadosAtuais() async {
    try {
      final snapshotCategorias = await _firestore.collection('categorias').get();
      final List<Map<String, String>> listaTemporaria = [];

      for (var doc in snapshotCategorias.docs) {
        listaTemporaria.add({'id': doc.id, 'nome': doc.get('nome') ?? ''});
      }

      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      if (mounted) {
        setState(() {
          _categoriasLojas = listaTemporaria;
          _carregarEstados();
          if (docLoja.exists) {
            final dados = docLoja.data() as Map<String, dynamic>;

            _nomeController.text = dados['nome'] ?? '';
            _descricaoInicial = dados['descricao'] ?? '';
            _enderecoController.text = dados['endereco'] ?? '';
            _nomeContatoCtrl.text = dados['nome_contato'] ?? '';
            _whatsappController.text = dados['telefone_whatsapp'] ?? '';
            _fixoController.text = dados['telefone_fixo'] ?? '';
            _tempoEntregaController.text = dados['tempo_entrega'] ?? '30-45 min';
            _fazDelivery = dados['is_delivery'] ?? true;
            _logoUrl = dados['logo_url'] ?? '';
            _taxaEntregaController.text = (dados['taxa_entrega'] != null) ? dados['taxa_entrega'].toString() : '';

            FirebaseFirestore.instance.collection('cidades').doc('${dados['cidade_id']}').get().then((snapshot) {
              if (snapshot.exists && mounted) {
                setState(() {
                  _estadoSelecionado = snapshot.data()?['uf'] ?? '';
                  _buscarCidadesPorEstado(_estadoSelecionado!);
                  _cidadeSelecionada = snapshot.id;
                });
              }
            });

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

  Future<void> _escolherEEnviarFoto() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);

    if (resultado != null && resultado.files.first.bytes != null) {
      setState(() => _subindoFoto = true);

      try {
        final arquivoBytes = resultado.files.first.bytes!;
        final nomeArquivo = resultado.files.first.name;
        final extensao = nomeArquivo.split('.').last;

        final ref = _storage.ref().child('logos_estabelecimentos/${widget.lojaId}.$extensao');
        UploadTask uploadTask = ref.putData(arquivoBytes, SettableMetadata(contentType: 'image/$extensao'));

        TaskSnapshot snapshot = await uploadTask;
        String urlPublica = await snapshot.ref.getDownloadURL();

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
        'nome_contato': _nomeContatoCtrl.text.trim(),
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

    final bool ehCelular = MediaQuery.of(context).size.width < 800;

    // Widgets auxiliares para construção dos campos responsivos sô!
    final inputNome = TextFormField(
      controller: _nomeController,
      decoration: InputDecoration(
        labelText: 'Nome da Loja',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (val) => val!.isEmpty ? 'O nome não pode ficar vazio.' : null,
    );

    final dropdownCategoria = DropdownButtonFormField<String>(
      value: _categoriaSelecionadaId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Ramo de Atividade',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _categoriasLojas.map((cat) {
        return DropdownMenuItem<String>(
          value: cat['id'],
          child: Text(cat['nome']!, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (id) => setState(() => _categoriaSelecionadaId = id),
    );

    final inputTempo = TextFormField(
      controller: _tempoEntregaController,
      decoration: InputDecoration(
        labelText: 'Tempo de Entrega (Ex: 30-45 min)',
        prefixIcon: const Icon(Icons.timer_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final inputTaxa = TextFormField(
      controller: _taxaEntregaController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Taxa de Entrega (R\$)', hintText: '0,00', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on_rounded)),
    );

    final dropdownEstado = DropdownButtonFormField<String>(
      value: _estadoSelecionado,
      decoration: const InputDecoration(labelText: 'Estado (UF)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.map_outlined)),
      items: _estados.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
      onChanged: (novoEstado) {
        if (novoEstado != null) {
          setState(() => _estadoSelecionado = novoEstado);
          _buscarCidadesPorEstado(novoEstado);
        }
      },
      validator: (value) => value == null ? 'Selecione o estado' : null,
    );

    final dropdownCidade = DropdownButtonFormField<String>(
      value: _cidadeSelecionada,
      disabledHint: Text(_carregandoCidades ? 'Buscando...' : 'Selecione o Estado'),
      decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city_rounded)),
      items: _cidades.isNotEmpty
          ? _cidades
                .map(
                  (cidade) => DropdownMenuItem<String>(
                    value: cidade['id'],
                    child: Text(cidade['nome'] ?? '', overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList()
          : null,
      onChanged: _cidades.isNotEmpty ? (novoIdCidade) => setState(() => _cidadeSelecionada = novoIdCidade) : null,
      validator: (value) => value == null ? 'Selecione a cidade' : null,
    );

    final inputWhatsapp = TextFormField(
      controller: _whatsappController,
      keyboardType: TextInputType.phone,
      maxLength: 15,
      decoration: InputDecoration(
        labelText: 'WhatsApp (com DDD)',
        prefixIcon: const Icon(Icons.phone_android, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          // 1. Remove tudo o que não for número sô
          String texto = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

          // Se o lojista estiver apagando, deixa o homem trabalhar em paz sô
          if (newValue.text.length < oldValue.text.length) {
            return newValue;
          }

          String textoFormatado = "";

          // 2. Monta a máscara certinha sem espaços duplicados sô!
          if (texto.length > 0) {
            textoFormatado += "(${texto.substring(0, texto.length.clamp(0, 2))}";
          }
          if (texto.length > 2) {
            // Juntamos o fecha parêntese com o espaço padrão sô: ") "
            textoFormatado += ") ${texto.substring(2, texto.length.clamp(2, 7))}";
          }
          if (texto.length > 7) {
            // Corta os primeiros 5 dígitos do número e mete o hífen pro restante sô
            textoFormatado = "(${texto.substring(0, 2)}) ${texto.substring(2, 7)}-${texto.substring(7, texto.length.clamp(7, 11))}";
          }

          return TextEditingValue(
            text: textoFormatado,
            selection: TextSelection.collapsed(offset: textoFormatado.length),
          );
        }),
      ],
      validator: (val) => val!.isEmpty ? 'O WhatsApp é obrigatório.' : null,
    );

    final inputFixo = TextFormField(
      controller: _fixoController,
      maxLength: 15,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Telefone Fixo (Opcional)',
        prefixIcon: const Icon(Icons.phone, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          // 1. Remove tudo o que não for número sô
          String texto = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

          // Se o lojista estiver apagando, deixa o homem trabalhar em paz sô
          if (newValue.text.length < oldValue.text.length) {
            return newValue;
          }

          String textoFormatado = "";

          // 2. Monta a máscara certinha sem espaços duplicados sô!
          if (texto.length > 0) {
            textoFormatado += "(${texto.substring(0, texto.length.clamp(0, 2))}";
          }
          if (texto.length > 2) {
            // Juntamos o fecha parêntese com o espaço padrão sô: ") "
            textoFormatado += ") ${texto.substring(2, texto.length.clamp(2, 7))}";
          }
          if (texto.length > 7) {
            // Corta os primeiros 5 dígitos do número e mete o hífen pro restante sô
            textoFormatado = "(${texto.substring(0, 2)}) ${texto.substring(2, 7)}-${texto.substring(7, texto.length.clamp(7, 11))}";
          }

          return TextEditingValue(
            text: textoFormatado,
            selection: TextSelection.collapsed(offset: textoFormatado.length),
          );
        }),
      ],
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(ehCelular ? 10.0 : 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏪 Perfil do Estabelecimento',
                style: TextStyle(fontSize: ehCelular ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              const Text('Mantenha as configurações, logo e contatos da sua loja atualizados para o aplicativo.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              SizedBox(height: ehCelular ? 20 : 32),

              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: EdgeInsets.all(ehCelular ? 16.0 : 16.0),
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
                        const SizedBox(height: 34),
                        QrCodeBotaoWidget(lojaId: widget.lojaId, nomeLoja: _nomeController.text),
                        const SizedBox(height: 32),

                        // BLOCO 1: NOME E CATEGORIA
                        if (ehCelular) ...[
                          inputNome,
                          const SizedBox(height: 16),
                          dropdownCategoria,
                        ] else ...[
                          Row(
                            children: [
                              Expanded(flex: 6, child: inputNome),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: dropdownCategoria),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),
                        // ENDEREÇO FÍSICO
                        TextField(
                          controller: _nomeContatoCtrl,
                          maxLength: 50,
                          decoration: InputDecoration(
                            labelText: 'Nome do Responsável / Contato',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFFE65100)),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),

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
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(_fazDelivery ? Icons.delivery_dining : Icons.storefront, color: _fazDelivery ? const Color(0xFFE65100) : Colors.grey[600]),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Realiza Entregas (Delivery)?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(
                                            _fazDelivery ? 'Ativo: Pedidos para entregar.' : 'Inativo: Apenas balcão.',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(value: _fazDelivery, activeColor: const Color(0xFFE65100), onChanged: (val) => setState(() => _fazDelivery = val)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // BLOCO 2: TEMPO E TAXA (APENAS SE DELIVERY ESTIVER ATIVO)
                        if (_fazDelivery) ...[
                          if (ehCelular) ...[
                            inputTempo,
                            const SizedBox(height: 16),
                            inputTaxa,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputTempo),
                                const SizedBox(width: 16),
                                Expanded(child: inputTaxa),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],

                        // BLOCO 3: ESTADO E CIDADE
                        if (ehCelular) ...[
                          dropdownEstado,
                          const SizedBox(height: 16),
                          dropdownCidade,
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: dropdownEstado),
                              const SizedBox(width: 16),
                              Expanded(child: dropdownCidade),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ENDEREÇO FÍSICO
                        TextFormField(
                          controller: _enderecoController,
                          decoration: InputDecoration(
                            labelText: 'Endereço Físico',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) => val!.isEmpty ? 'Informe o endereço.' : null,
                        ),
                        const SizedBox(height: 16),

                        // BLOCO 4: WHATSAPP E FIXO
                        if (ehCelular) ...[
                          inputWhatsapp,
                          const SizedBox(height: 16),
                          inputFixo,
                        ] else ...[
                          Row(
                            children: [
                              Expanded(flex: 4, child: inputWhatsapp),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: inputFixo),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),

                        // BLOCO EDITOR RICH TEXT (HTML)
                        Text('* Descrição da loja, horários de atendimento ou outras informações importantes.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: HtmlEditor(
                            controller: _descricaoEditorController,
                            htmlEditorOptions: HtmlEditorOptions(
                              hint: "Ex: <b>Dias de atendimento:</b> Quarta a Domingo...",
                              initialText: _descricaoInicial,
                              shouldEnsureVisible: true,
                              autoAdjustHeight: true,
                            ),
                            htmlToolbarOptions: const HtmlToolbarOptions(
                              toolbarPosition: ToolbarPosition.aboveEditor,
                              toolbarType: ToolbarType.nativeScrollable, // Permite arrastar os botões no toque do celular sô!
                              defaultToolbarButtons: [
                                FontSettingButtons(fontSize: true),
                                FontButtons(bold: true, italic: true, underline: true, clearAll: true),
                                ColorButtons(foregroundColor: true),
                                ListButtons(ul: true, ol: true),
                                ParagraphButtons(alignLeft: true, alignCenter: true, alignRight: true),
                              ],
                            ),
                            otherOptions: const OtherOptions(height: 200),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // BOTÃO SALVAR ALTERAÇÕES ADAPTATIVO
                        SizedBox(
                          height: 50,
                          width: ehCelular ? double.infinity : 220, // Ocupa a tela inteira no celular sô!
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
