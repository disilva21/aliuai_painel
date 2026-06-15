import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class CadastroProdutoModal extends StatefulWidget {
  final Map<String, dynamic>? produtoExistente; // Para edições de produto
  final String lojaId;
  final String categoriaLoja; // Recebe o ID do nicho pai tratado (ex: 'cat_restaurantes')
  final String? idProduto; // ID do produto para edição, se aplicável

  const CadastroProdutoModal({super.key, this.produtoExistente, required this.lojaId, required this.categoriaLoja, this.idProduto});

  @override
  State<CadastroProdutoModal> createState() => _CadastroProdutoModalState();
}

class _CadastroProdutoModalState extends State<CadastroProdutoModal> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _precoController = TextEditingController();
  final _descricaoController = TextEditingController();

  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _subindoFoto = false;
  String _fotoUrl = '';

  bool _salvando = false;
  String? _categoriaSelecionada; // Armazena o slug em minúsculo sô!

  // 📡 Lista dinâmica das categorias filtradas por nicho pai sô
  List<Map<String, dynamic>> _categoriasFiltradas = [];
  bool _carregandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _carregarCategoriasPorNicho();

    // Se um produto existente for passado, pré-preenche os campos para edição
    if (widget.produtoExistente != null) {
      _nomeController.text = widget.produtoExistente!['nome'] ?? '';
      _precoController.text = widget.produtoExistente!['preco'].toString();
      _descricaoController.text = widget.produtoExistente!['descricao'] ?? '';
      _fotoUrl = widget.produtoExistente!['foto_url'] ?? '';
      _categoriaSelecionada = widget.produtoExistente!['categoria_id']; // Resgata o slug salvo sô
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  /// 🛠️ Busca apenas as subcategorias permitidas para o nicho desta loja sô!
  Future<void> _carregarCategoriasPorNicho() async {
    try {
      final snapshot = await _firestore.collection('categoria_produto').where('estabelecimentos_permitidos', arrayContains: widget.categoriaLoja).where('ativo', isEqualTo: true).get();

      final List<Map<String, dynamic>> carregadas = snapshot.docs.map((doc) {
        final dados = doc.data();
        return {
          'slug': dados['slug'] ?? doc.id, // ID tratado em minúsculo sô!
          'nome': dados['nome'].toString(), // Nome com maiúscula para exibição
        };
      }).toList();

      // Ordena por ordem alfabética o nome bonito sô!
      carregadas.sort((a, b) => a['nome'].compareTo(b['nome']));

      if (mounted) {
        setState(() {
          _categoriasFiltradas = carregadas;
          _carregandoCategorias = false;

          // Se não for edição e tiver dados, pré-seleciona a primeira opção
          if (_categoriaSelecionada == null && _categoriasFiltradas.isNotEmpty) {
            _categoriaSelecionada = _categoriasFiltradas.first['slug'];
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias por nicho sô: $e');
      if (mounted) setState(() => _carregandoCategorias = false);
    }
  }

  /// Upload de foto em Bytes para Flutter Web
  Future<void> _escolherEEnviarFoto() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);

    if (resultado != null && resultado.files.first.bytes != null) {
      setState(() => _subindoFoto = true);

      try {
        final arquivoBytes = resultado.files.first.bytes!;
        final nomeArquivo = resultado.files.first.name;
        final extensao = nomeArquivo.split('.').last;
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

        final ref = _storage.ref().child('produtos/${widget.lojaId}_$timestamp.$extensao');

        UploadTask uploadTask = ref.putData(arquivoBytes, SettableMetadata(contentType: 'image/$extensao'));

        TaskSnapshot snapshot = await uploadTask;
        String urlPublica = await snapshot.ref.getDownloadURL();

        if (mounted) {
          setState(() {
            _fotoUrl = urlPublica;
            _subindoFoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto atualizada! 📸'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _subindoFoto = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// 🔥 MÉTODO DE SALVAMENTO AJUSTADO: Alinhamento perfeito com o Filtro sô!
  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate() || _categoriaSelecionada == null) return;

    setState(() => _salvando = true);

    final precoTexto = _precoController.text.trim().replaceAll(',', '.');
    final precoDouble = double.tryParse(precoTexto) ?? 0.0;

    try {
      // 🧠 Extrai os dados exatos do item selecionado na lista filtrada sô!
      final catObjeto = _categoriasFiltradas.firstWhere((cat) => cat['slug'] == _categoriaSelecionada);
      final String nomeCategoriaBonito = catObjeto['nome']; // Ex: "Refeições / Prato Feito"
      final String slugCategoriaMinusc = catObjeto['slug']; // Ex: "refeicoes_prato_feito"

      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();
      String cidadeIdDaLoja = '';

      if (docLoja.exists) {
        final dadosLoja = docLoja.data();
        cidadeIdDaLoja = dadosLoja?['cidade_id'] ?? '';
      }

      final produtoData = {
        'nome': _nomeController.text.trim(),
        'preco': precoDouble,
        'descricao': _descricaoController.text.trim(),

        // 🚨 AS DUAS CHAVES SINCROZINADAS AQUI SÔ:
        'categoria_id': slugCategoriaMinusc, // 🔥 Salva minúsculo pro FILTRO funcionar!
        'categoria_produto': nomeCategoriaBonito, // Salva o nome bonito para a tela do cliente!

        'foto_url': _fotoUrl,
      };

      if (widget.produtoExistente != null) {
        await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').doc(widget.idProduto).update({...produtoData, 'alterado_em': FieldValue.serverTimestamp()});
      } else {
        await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').add({
          ...produtoData,
          'disponivel': true,
          'criado_em': FieldValue.serverTimestamp(),
          'estabelecimento_id': widget.lojaId,
          'promocao': false,
          'cidade_id': cidadeIdDaLoja,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo com sucesso! 🎉'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('Erro ao salvar produto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar o produto: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.add_box, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Text(widget.produtoExistente != null ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _carregandoCategorias
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
              )
            : _categoriasFiltradas.isEmpty
            ? SizedBox(height: 100, child: Center(child: Text('Nenhuma subcategoria liberada para o nicho "${widget.categoriaLoja}" sô! 🌾')))
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // NOME DO PRODUTO
                      TextFormField(
                        controller: _nomeController,
                        decoration: InputDecoration(
                          labelText: 'Nome do Produto',
                          hintText: 'Ex: X-Burguer Artesanal, Blusa Polo...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Digite o nome do produto.' : null,
                      ),
                      const SizedBox(height: 16),

                      // PREÇO E CATEGORIA DO PRODUTO
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _precoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Preço de Venda',
                                hintText: '0,00',
                                prefixText: 'R\$ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Digite o preço.';
                                final formatado = val.replaceAll(',', '.');
                                if (double.tryParse(formatado) == null) return 'Valor inválido.';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // DROPDOWN RESPONSIVO E ADAPTADO PARA TEXTOS COMPRIDOS SÔ!
                          Expanded(
                            flex: 7,
                            child: DropdownButtonFormField<String>(
                              value: _categoriaSelecionada,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Seção / Categoria',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              ),
                              items: _categoriasFiltradas.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['slug'], // Mapeia o valor em minúsculo de forma segura
                                  child: Text(
                                    cat['nome'], // Nome bonito com acentos e maiúsculas sô
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _categoriaSelecionada = val),
                              validator: (val) => val == null ? 'Selecione uma categoria.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // DESCRIÇÃO DO PRODUTO
                      TextFormField(
                        controller: _descricaoController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descrição / Detalhes',
                          hintText: 'Ex: Ingredientes ou detalhes do produto...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Insira uma descrição.' : null,
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey[300]!, width: 2),
                            ),
                            child: _subindoFoto
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)))
                                : _fotoUrl.isNotEmpty
                                ? Builder(
                                    builder: (context) {
                                      final String viewId = 'logo-${_fotoUrl.hashCode}';
                                      ui_web.platformViewRegistry.registerViewFactory(
                                        viewId,
                                        (int viewId) => html.ImageElement()
                                          ..src = _fotoUrl
                                          ..style.width = '100%'
                                          ..style.height = '100%'
                                          ..style.objectFit = 'cover',
                                      );
                                      return HtmlElementView(viewType: viewId);
                                    },
                                  )
                                : Icon(Icons.add_business, size: 45, color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE65100)),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Foto do Produto (PNG/JPG)', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _subindoFoto ? null : _escolherEEnviarFoto,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: _salvando ? null : _salvarProduto,
          child: _salvando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Salvar Produto', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
