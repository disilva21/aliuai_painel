import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:html' as html; // 🌐 Fiação nativa para download na Web sô!

class DialogPanfleto extends StatefulWidget {
  final Map<String, dynamic> produto;
  final String nomeLoja;
  final String idLoja;

  const DialogPanfleto({super.key, required this.produto, required this.nomeLoja, required this.idLoja});

  @override
  State<DialogPanfleto> createState() => _DialogPanfletoState();
}

class _DialogPanfletoState extends State<DialogPanfleto> {
  final GlobalKey _globalKeyPanfleto = GlobalKey();
  bool _gerandoImagem = false;

  // Opções de personalização
  Color _corFundoSelecionada = const Color(0xFF1E1E26);
  String _chamadaTopo = "OFERTA ESPECIAL DO DIA! 🎉";

  final List<Map<String, dynamic>> _paletaCores = [
    {'nome': 'Dark Aliuai', 'cor': const Color(0xFF1E1E26)},
    {'nome': 'Laranja Uai', 'cor': const Color(0xFFE65100)},
    {'nome': 'Branco Clean', 'cor': const Color(0xFFF5F5F5)},
    {'nome': 'Verde Pix', 'cor': const Color(0xFF004D40)},
  ];

  /// 📥 MOTOR DE EXPORTAÇÃO
  Future<void> _exportarPanfletoParaPng() async {
    setState(() => _gerandoImagem = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      RenderRepaintBoundary boundary = _globalKeyPanfleto.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final blob = html.Blob([pngBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "panfleto_${widget.produto['nome'] ?? 'oferta'}.png")
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Panfleto digital gerado e baixado com sucesso! 📸🚀'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print("Erro na fiação de captura do panfleto sô: $e");
    } finally {
      if (mounted) setState(() => _gerandoImagem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double precoAtual = double.tryParse(widget.produto['preco']?.toString() ?? '0') ?? 0;
    double precoPromocional = double.tryParse(widget.produto['preco_promocional']?.toString() ?? '0') ?? 0;
    String urlFoto = widget.produto['foto_url'] ?? 'https://placehold.co/300';
    String nomeProduto = widget.produto['nome'] ?? 'Produto sem nome';

    bool isLight = _corFundoSelecionada == const Color(0xFFF5F5F5);
    Color corTextoPrincipal = isLight ? Colors.black87 : Colors.white;
    Color corTextoSecundario = isLight ? Colors.grey[700]! : Colors.white70;

    // 📱 DETECTOR DE TAMANHO DE TELA SÔ!
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 800;

    // 🛠️ COMPONENTE: Painel de Controles (Formulário)
    Widget construirControles() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Personalize o seu Encarte:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _chamadaTopo,
            decoration: const InputDecoration(labelText: 'Texto de Destaque Superior', border: OutlineInputBorder()),
            onChanged: (val) => setState(() => _chamadaTopo = val.toUpperCase()),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cor de Fundo do Panfleto:',
            style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paletaCores.map((item) {
              bool selecionada = _corFundoSelecionada == item['cor'];
              return ChoiceChip(
                label: Text(item['nome'], style: TextStyle(color: selecionada ? Colors.white : Colors.black87)),
                selected: selecionada,
                selectedColor: const Color(0xFFE65100),
                backgroundColor: Colors.grey[200],
                onSelected: (bool selected) {
                  if (selected) setState(() => _corFundoSelecionada = item['cor']);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              icon: _gerandoImagem ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.download_rounded),
              label: Text(_gerandoImagem ? 'Processando Imagem...' : 'Baixar Imagem PNG'),
              onPressed: _gerandoImagem ? null : _exportarPanfletoParaPng,
            ),
          ),
        ],
      );
    }

    // 🎨 COMPONENTE: O Panfleto 9:16 Puro sô!
    Widget construirPreviewPanfleto() {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        // 🚀 O FITTEDBOX É A VACINA: Encolhe o panfleto pra caber em qualquer celular sem quebrar!
        child: FittedBox(
          fit: BoxFit.contain,
          child: RepaintBoundary(
            key: _globalKeyPanfleto,
            child: Container(
              width: 360,
              height: 640,
              color: _corFundoSelecionada,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        widget.nomeLoja.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: corTextoSecundario, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _chamadaTopo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      image: DecorationImage(image: NetworkImage(urlFoto), fit: BoxFit.cover),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        nomeProduto,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: corTextoPrincipal, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFFE65100), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            if (precoPromocional > 0)
                              Text(
                                'De: R\$ ${precoAtual.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w500),
                              ),
                            Text(
                              'Por: R\$ ${precoPromocional.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Acesse o nosso catálogo para pedir! 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: corTextoSecundario, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Catálogo Oficial no aplicativo Aliuai 🌌',
                        style: TextStyle(color: corTextoSecundario.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'https://aliuai.com.br/loja/${widget.idLoja}',
                        style: TextStyle(color: corTextoSecundario.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      contentPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.campaign, color: Color(0xFFE65100), size: 26),
          SizedBox(width: 12),
          Text('Panfleto de Ofertas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        // Força uma largura boa se for computador, ou deixa livre se for celular sô!
        width: ehCelular ? double.maxFinite : 750,
        child: SingleChildScrollView(
          child: ehCelular
              ? Column(
                  // 📱 SE FOR CELULAR: Coloca o panfleto em cima e os botões embaixo sô!
                  children: [
                    SizedBox(height: 380, child: construirPreviewPanfleto()),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    construirControles(),
                  ],
                )
              : Row(
                  // 💻 SE FOR COMPUTADOR: Mantém lado a lado chique demais!
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: construirControles()),
                    const SizedBox(width: 40),
                    Expanded(flex: 6, child: SizedBox(height: 500, child: construirPreviewPanfleto())),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Fechar',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
