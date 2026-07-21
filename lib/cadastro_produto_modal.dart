import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:crop_your_image/crop_your_image.dart'; // 🚀 NOVO: Biblioteca mestre do corte sô!

class CadastroProdutoModal extends StatefulWidget {
  final Map<String, dynamic>? produtoExisting; // Para edições de produto
  final String lojaId;
  final String categoriaLoja;
  final String? idProduto;

  const CadastroProdutoModal({super.key, this.produtoExisting, required this.lojaId, required this.categoriaLoja, this.idProduto});

  @override
  State<CadastroProdutoModal> createState() => _CadastroProdutoModalState();
}

class _CadastroProdutoModalState extends State<CadastroProdutoModal> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _precoController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _codigoController = TextEditingController();

  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _subindoFoto = false;
  String _fotoUrl = '';

  bool _salvando = false;
  String? _categoriaSelecionada;

  List<Map<String, dynamic>> _categoriasFiltradas = [];
  bool _carregandoCategorias = true;

  // 🚀 NOVO: Estado de controle para o Crop em memória sô!
  final CropController _cropController = CropController();
  Uint8List? _bytesImagemOriginal;
  bool _modoCorteAtivo = false;
  String _extensaoArquivoOriginal = 'jpg';

  @override
  void initState() {
    super.initState();
    _carregarCategoriasPorNicho();

    if (widget.produtoExisting != null) {
      _nomeController.text = widget.produtoExisting!['nome'] ?? '';
      _precoController.text = widget.produtoExisting!['preco'].toString();
      _descricaoController.text = widget.produtoExisting!['descricao'] ?? '';
      _codigoController.text = widget.produtoExisting!['codigo'] ?? '';
      _fotoUrl = widget.produtoExisting!['foto_url'] ?? '';
      _categoriaSelecionada = widget.produtoExisting!['categoria_id'];
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _descricaoController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _carregarCategoriasPorNicho() async {
    try {
      final snapshot = await _firestore.collection('categoria_produto').where('estabelecimentos_permitidos', arrayContains: widget.categoriaLoja).where('ativo', isEqualTo: true).get();

      final List<Map<String, dynamic>> carregadas = snapshot.docs.map((doc) {
        final dados = doc.data();
        return {'slug': dados['slug'] ?? doc.id, 'nome': dados['nome'].toString()};
      }).toList();

      carregadas.sort((a, b) => a['nome'].compareTo(b['nome']));

      if (mounted) {
        setState(() {
          _categoriasFiltradas = carregadas;
          _carregandoCategorias = false;

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

  /// 📸 PASSO A: Escolhe o arquivo e ativa a mesa de corte interna sô!
  Future<void> _escolherFotoOriginal() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);

    if (resultado != null && resultado.files.first.bytes != null) {
      final nomeArquivo = resultado.files.first.name;
      setState(() {
        _bytesImagemOriginal = resultado.files.first.bytes;
        _extensaoArquivoOriginal = nomeArquivo.split('.').last.toLowerCase();
        _modoCorteAtivo = true; // 🎛️ Ativa a mesa de corte na tela uai!
      });
    }
  }

  /// 📸 PASSO B: Processa os bytes recortados em 1:1 e faz o despacho pro Storage sô!
  Future<void> _fazerUploadBytesRecortados(Uint8List bytesRecortados) async {
    setState(() {
      _modoCorteAtivo = false;
      _subindoFoto = true;
    });

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref().child('produtos/${widget.lojaId}_$timestamp.$_extensaoArquivoOriginal');

      UploadTask uploadTask = ref.putData(bytesRecortados, SettableMetadata(contentType: 'image/$_extensaoArquivoOriginal'));

      TaskSnapshot snapshot = await uploadTask;
      String urlPublica = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _fotoUrl = urlPublica;
          _subindoFoto = false;
          _bytesImagemOriginal = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto recortada e atualizada com sucesso! 📸✂️'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subindoFoto = false;
          _bytesImagemOriginal = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar imagem recortada: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate() || _categoriaSelecionada == null) return;

    setState(() => _salvando = true);

    final precoTexto = _precoController.text.trim().replaceAll(',', '.');
    final precoDouble = double.tryParse(precoTexto) ?? 0.0;
    final String? codigoDigitado = _codigoController.text.trim().isNotEmpty ? _codigoController.text.trim() : null;

    try {
      final catObjeto = _categoriasFiltradas.firstWhere((cat) => cat['slug'] == _categoriaSelecionada);
      final String nomeCategoriaBonito = catObjeto['nome'];
      final String slugCategoriaMinusc = catObjeto['slug'];

      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();
      List<String> todasAsCidades = [];
      String idDaCidadeSede = '';
      if (docLoja.exists) {
        final dadosLoja = docLoja.data();

        idDaCidadeSede = dadosLoja?['cidade_id'] ?? '';
        todasAsCidades = [idDaCidadeSede];

        if (dadosLoja?['cidades_expansao'] != null) {
          // 🎯 AQUI ESTÁ A CORREÇÃO: Converte o JSArray<dynamic> para List<String> de forma segura!
          List<String> idsExpansao = List<String>.from(dadosLoja?['cidades_expansao']);

          todasAsCidades.addAll(idsExpansao);
        }
      }

      final produtoData = {
        'nome': _nomeController.text.trim(),
        'preco': precoDouble,
        'descricao': _descricaoController.text.trim(),
        'categoria_id': slugCategoriaMinusc,
        'categoria_produto': nomeCategoriaBonito,
        'foto_url': _fotoUrl,
      };

      final subColecaoProdutos = _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos');

      if (widget.produtoExisting != null) {
        await subColecaoProdutos.doc(widget.idProduto).update({...produtoData, 'codigo': codigoDigitado ?? widget.idProduto, 'alterado_em': FieldValue.serverTimestamp()});
      } else {
        DocumentReference docRef;
        String codigoFinal;

        if (codigoDigitado != null) {
          codigoFinal = codigoDigitado;
          docRef = subColecaoProdutos.doc(codigoFinal);
        } else {
          docRef = subColecaoProdutos.doc();
          codigoFinal = docRef.id;
        }

        await docRef.set({
          ...produtoData,
          'id': docRef.id,
          'codigo': codigoFinal,
          'disponivel': true,
          'criado_em': FieldValue.serverTimestamp(),
          'estabelecimento_id': widget.lojaId,
          'promocao': false,
          'cidade_id': idDaCidadeSede,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto salvo com sucesso! 🎉'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("====== TESTE DE FILTRAÇÃO DO GERENTE ======");
      print("1. ID DA LOJA REAL: ${widget.lojaId}");
      print("2. UID DO COMPANHEIRO LOGADO: ${FirebaseAuth.instance.currentUser?.uid}");
      print("3. EMAIL DO LOGADO: ${FirebaseAuth.instance.currentUser?.email}");
      print("===========================================");
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
              Text(widget.produtoExisting != null ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            : _modoCorteAtivo && _bytesImagemOriginal != null
            // 🎛️ INTERFACE DE CORTE ATIVA: Entra no lugar do formulário temporariamente sô!
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ajuste o Enquadramento Quadrado (16:10) sô:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 300,
                    width: 400,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Crop(
                      image: _bytesImagemOriginal!,
                      controller: _cropController,
                      aspectRatio: 16 / 10,

                      // 🚀 ATUALIZADO: Abrimos a caixinha 'result' para pegar os bytes reais sô!
                      onCropped: (result) {
                        if (result is CropSuccess) {
                          // Se o corte deu certo, passamos os bytes (result.image) pro seu método de upload!
                          _fazerUploadBytesRecortados(result.croppedImage);
                        } else if (result is CropFailure) {
                          // Se deu algum chabu no corte, avisamos o lojista sô
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao cortar a imagem sô! Tente novamente.'), backgroundColor: Colors.red));
                          setState(() {
                            _modoCorteAtivo = false;
                            _bytesImagemOriginal = null;
                          });
                        }
                      },

                      interactive: true,
                      baseColor: Colors.white,
                      maskColor: Colors.black.withOpacity(0.5),
                      cornerDotBuilder: (size, edgeIndex) => const DotControl(color: Color(0xFFE65100)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _modoCorteAtivo = false;
                          _bytesImagemOriginal = null;
                        }),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        icon: const Icon(Icons.crop),
                        label: const Text('Confirmar Corte e Subir', style: TextStyle(fontWeight: FontWeight.bold)),
                        // Dispara o gatilho que executa o onCropped acima sô!
                        onPressed: () => _cropController.crop(),
                      ),
                    ],
                  ),
                ],
              )
            // 📝 FORMULÁRIO PADRÃO DO PRODUTO sô!
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                  value: cat['slug'],
                                  child: Text(cat['nome'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _categoriaSelecionada = val),
                              validator: (val) => val == null ? 'Selecione uma categoria.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codigoController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(labelText: 'Código de Barras (Opcional) 🏷️', hintText: 'Bipe o código de barras ou deixe em branco', border: OutlineInputBorder()),
                        onSubmitted: (valor) {
                          if (valor.isNotEmpty) print('Bipou o código: $valor');
                        },
                      ),

                      const SizedBox(height: 16),

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
                            width: 250,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              // shape: BoxShape.circle,
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
                            onPressed: _subindoFoto ? null : _escolherFotoOriginal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: _modoCorteAtivo
          ? null // Oculta as ações do form principal quando estiver cortando sô
          : [
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
