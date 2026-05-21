import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class CadastroProdutoModal extends StatefulWidget {
  final Map<String, dynamic>? produtoExistente; // Para futuras edições de produto
  final String lojaId;
  final String? idProduto; // ID do produto para edição, se aplicável

  const CadastroProdutoModal({super.key, this.produtoExistente, required this.lojaId, this.idProduto});

  @override
  State<CadastroProdutoModal> createState() => _CadastroProdutoModalState();
}

class _CadastroProdutoModalState extends State<CadastroProdutoModal> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _precoController = TextEditingController();
  final _descricaoController = TextEditingController();

  final _storage = FirebaseStorage.instance;

  bool _subindoFoto = false;
  String _fotoUrl = '';

  bool _salvando = false;
  String _categoriaSelecionada = 'Lanches'; // Valor padrão inicial

  // Lista de categorias de produtos para o lojista organizar o cardápio dele
  final List<String> _categoriasProdutos = ['Lanches', 'Bebidas', 'Porções', 'Sobremesas', 'Moda Masculina', 'Moda Feminina', 'Outros'];

  @override
  void initState() {
    super.initState();

    // Se um produto existente for passado, pré-preenche os campos para edição
    if (widget.produtoExistente != null) {
      _nomeController.text = widget.produtoExistente!['nome'] ?? '';
      _precoController.text = widget.produtoExistente!['preco'].toString();
      _descricaoController.text = widget.produtoExistente!['descricao'] ?? '';
      _fotoUrl = widget.produtoExistente!['foto_url'] ?? '';
      _categoriaSelecionada = widget.produtoExistente!['categoria_produto'] ?? 'Lanches';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _descricaoController.dispose();
    super.dispose();
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
        final ref = _storage.ref().child('produtos/${widget.lojaId}.$extensao');

        // 4. Executa o upload em Bytes para Flutter Web
        UploadTask uploadTask = ref.putData(arquivoBytes, SettableMetadata(contentType: 'image/$extensao'));

        TaskSnapshot snapshot = await uploadTask;
        String urlPublica = await snapshot.ref.getDownloadURL();

        // // 5. Atualiza o banco com o novo link da foto
        // await _firestore.collection('estabelecimentos').doc(widget.lojaId).update({'logo_url': urlPublica});

        if (mounted) {
          setState(() {
            _fotoUrl = urlPublica;
            _subindoFoto = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto atualizada com sucesso! 📸'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _subindoFoto = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final precoTexto = _precoController.text.trim().replaceAll(',', '.');
    final precoDouble = double.tryParse(precoTexto) ?? 0.0;

    try {
      final docLoja = await FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).get();

      String cidadeIdDaLoja = '';

      if (docLoja.exists) {
        final dadosLoja = docLoja.data();

        cidadeIdDaLoja = dadosLoja?['cidade_id'] ?? ''; // 🔥 Puxa o ID salvo no perfil da loja
      }

      if (widget.produtoExistente != null) {
        await FirebaseFirestore.instance
            .collection('estabelecimentos')
            .doc(widget.lojaId) // ID da loja logada
            .collection('produtos') // Subcoleção de produtos daquela loja
            .doc(widget.idProduto) // ID do produto existente
            .update({
              'nome': _nomeController.text.trim(),
              'preco': precoDouble,
              'descricao': _descricaoController.text.trim(),
              'categoria_produto': _categoriaSelecionada,
              'foto_url': _fotoUrl,
              'alterado_em': FieldValue.serverTimestamp(),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('estabelecimentos')
            .doc(widget.lojaId) // ID da loja logada
            .collection('produtos') // Subcoleção de produtos daquela loja
            .add({
              'nome': _nomeController.text.trim(),
              'preco': precoDouble,
              'descricao': _descricaoController.text.trim(),
              'categoria_produto': _categoriaSelecionada,
              'disponivel': true,
              'foto_url': _fotoUrl,
              'criado_em': FieldValue.serverTimestamp(),
              'estabelecimento_id': widget.lojaId,
              'promocao': false,
              'cidade_id': cidadeIdDaLoja,
            });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto cadastrado com sucesso! 🎉'), backgroundColor: Colors.green));
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
          const Row(
            children: [
              Icon(Icons.add_box, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text('Cadastrar Novo Produto', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 500, // Largura ideal fixada para caixas Web
        child: SingleChildScrollView(
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
                    hintText: 'Ex: X-Burguer Artesanal, Blusa Polo, Gás P13...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Digite o nome do produto.' : null,
                ),
                const SizedBox(height: 16),

                // LINHA DUPLA: PREÇO E CATEGORIA DO PRODUTO
                Row(
                  children: [
                    // CAMPO PREÇO
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _precoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Preço de Venda (R\$)',
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
                    // SELETOR DE SEÇÃO DO CARDÁPIO
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        value: _categoriaSelecionada,
                        decoration: InputDecoration(
                          labelText: 'Seção / Categoria',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _categoriasProdutos.map((cat) {
                          return DropdownMenuItem<String>(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) => setState(() => _categoriaSelecionada = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DESCRIÇÃO DO PRODUTO
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3, // Deixa a caixa maior para caber os ingredientes/detalhes
                  decoration: InputDecoration(
                    labelText: 'Descrição / Detalhes',
                    hintText: 'Ex: Descreva o que vem no prato ou os tamanhos e cores disponíveis...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Insira uma descrição para seu cliente ler.' : null,
                ),
                SizedBox(height: 24),
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
                      child: Container(
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
        // BOTÃO CANCELAR
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        // BOTÃO SALVAR
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
