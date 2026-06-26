import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:html' as html; // 🌐 Fiação nativa para download na Web sô!
import 'package:qr_flutter/qr_flutter.dart'; // 🚀 NOVO: Biblioteca do QR Code inteligente!

class DialogPanfleto extends StatefulWidget {
  final Map<String, dynamic> produto;
  final String nomeLoja;
  final String idLoja;
  final String planoDaLoja;

  const DialogPanfleto({super.key, required this.produto, required this.nomeLoja, required this.idLoja, required this.planoDaLoja});

  @override
  State<DialogPanfleto> createState() => _DialogPanfletoState();
}

class _DialogPanfletoState extends State<DialogPanfleto> {
  final GlobalKey _globalKeyPanfleto = GlobalKey();
  bool _gerandoImagem = false;

  // Opções de personalização
  Color _corFundoSelecionada = const Color(0xFF1E1E26);
  String _chamadaTopo = "OFERTA ESPECIAL DO DIA! 🎉";

  // 🎨 PALETA ATUALIZADA: Guardamos o nome por contingência, mas focamos na cor sô!
  final List<Map<String, dynamic>> _paletaCores = [
    {'nome': 'Dark Aliuai', 'cor': const Color(0xFF1E1E26)},
    {'nome': 'Laranja Uai', 'cor': const Color(0xFFE65100)},
    {'nome': 'Branco Clean', 'cor': const Color(0xFFF5F5F5)},
    {'nome': 'Verde Pix', 'cor': const Color(0xFF004D40)},
    {'nome': 'Azul', 'cor': const ui.Color.fromARGB(255, 7, 88, 155)},
    {'nome': 'Lilas', 'cor': const ui.Color.fromARGB(255, 151, 3, 209)},
  ];

  void _mostrarAvisoUpgradePlano(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text('Recurso Exclusivo sô! 🌟'),
            ],
          ),
          content: const Text(
            'A criação de panfletos promocionais automáticos é um benefício do **Plano Master** uai!\n\n'
            'Com ele, você gera artes lindas dos seus produtos para bombar nas redes sociais e no WhatsApp no estalo de um clique.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E26),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                // 💳 Direciona o caboclo direto para a tela global de planos/pagamento uai!
                // Navigator.pushNamed(context, '/selecao_planos_pagamento');
              },
              child: const Text('Mude seu Plano 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// 📥 MOTOR DE EXPORTAÇÃO
  Future<void> _exportarPanfletoParaPng() async {
    setState(() => _gerandoImagem = true);

    try {
      if (widget.planoDaLoja.isEmpty || widget.planoDaLoja != 'master') {
        _mostrarAvisoUpgradePlano(context);

        return;
      }

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

    // 🔥 VÍNCULO DA SUA URLSTRATEGY: O link dinâmico da loja sô!
    String linkOficialLoja = "https://aliuai.com.br/loja/${widget.idLoja}";

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
          const SizedBox(height: 12),

          // 🎨 NOVO SELETOR DE CORES EM CÍRCULOS (ESTILO CHROMATIC DROPS sô!)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _paletaCores.map((item) {
              bool selecionada = _corFundoSelecionada == item['cor'];
              return GestureDetector(
                onTap: () => setState(() => _corFundoSelecionada = item['cor']),
                child: Tooltip(
                  message: item['nome'],
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item['cor'],
                      shape: BoxShape.circle,
                      border: Border.all(color: selecionada ? const Color(0xFFE65100) : Colors.grey[300]!, width: selecionada ? 3 : 1),
                      boxShadow: [if (selecionada) BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 6, spreadRadius: 1)],
                    ),
                    child: selecionada ? Icon(Icons.check_circle_rounded, size: 20, color: item['cor'] == const Color(0xFFF5F5F5) ? const Color(0xFFE65100) : Colors.white) : const SizedBox.shrink(),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

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

    // 🎨 COMPONENTE: O Panfleto 9:16 Puro com QR Code sô!
    Widget construirPreviewPanfleto() {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
        ),
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
                              'Por: R\$ ${precoPromocional > 0 ? precoPromocional.toStringAsFixed(2) : precoAtual.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 🌌 RODAPÉ ATUALIZADO: Layout Integrado com QR Code Dinâmico e Legendas sô!
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Aponte a câmera 📱',
                                textAlign: TextAlign.right,
                                style: TextStyle(color: corTextoPrincipal, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'e peça direto do catálogo!',
                                textAlign: TextAlign.right,
                                style: TextStyle(color: corTextoSecundario, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // 🏁 BLOCO DO QR CODE: Com contraste garantido em fundo branco
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                            ),
                            child: QrImageView(
                              data: linkOficialLoja, // 👈 Vinculado com a sua URLStrategy sô!
                              version: QrVersions.auto,
                              size: 80.0,
                              gapless: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Catálogo Oficial no aplicativo Aliuai 🌌',
                        style: TextStyle(color: corTextoSecundario.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'aliuai.com.br/loja/${widget.idLoja}',
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
        width: ehCelular ? double.maxFinite : 750,
        child: SingleChildScrollView(
          child: ehCelular
              ? Column(
                  children: [
                    SizedBox(height: 380, child: construirPreviewPanfleto()),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    construirControles(),
                  ],
                )
              : Row(
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
