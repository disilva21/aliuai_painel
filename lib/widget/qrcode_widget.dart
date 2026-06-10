import 'dart:convert';
import 'dart:math' as math;
import 'dart:html' as html; // Importação nativa para download na Web sô!

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeBotaoWidget extends StatelessWidget {
  final String lojaId;
  final String nomeLoja;

  const QrCodeBotaoWidget({super.key, required this.lojaId, required this.nomeLoja});

  /// 📥 Baixa o Expositor com fundo BRANCO (Econômico) e a Logo com BOX ESCURO!
  void _baixarQrCode() {
    final String urlLoja = 'https://aliuai.com.br/?loja=$lojaId';

    // 1. Instancia o pintor oficial do QR Code
    final qrPainter = QrPainter(
      data: urlLoja,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      color: const Color(0xFF1E1E26), // QR Code escuro para leitura perfeita no papel branco
      emptyColor: Colors.white,
    );

    const double larguraCanvas = 1200;
    const double alturaCanvas = 1800;

    qrPainter.toImageData(650).then((imageBytes) {
      if (imageBytes != null) {
        final bytesQr = imageBytes.buffer.asUint8List();
        final base64Qr = base64Encode(bytesQr);
        final qrDataUrl = 'data:image/png;base64,$base64Qr';

        final html.CanvasElement canvas = html.CanvasElement(width: larguraCanvas.toInt(), height: alturaCanvas.toInt());
        final html.CanvasRenderingContext2D ctx = canvas.context2D;

        // Ativa máxima nitidez sô!
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        final html.ImageElement imgQr = html.ImageElement();
        imgQr.src = qrDataUrl;

        imgQr.onLoad.listen((_) {
          // ⬜ LAYER 1: Fundo BRANCO em todo o papel (Economia de tinta garantida!)
          ctx.fillStyle = '#FFFFFF';
          ctx.fillRect(0, 0, larguraCanvas, alturaCanvas);

          // 🟠 LAYER 2: Faixa Laranja Premium bem fina no topo da folha
          ctx.fillStyle = '#E65100';
          ctx.fillRect(0, 0, larguraCanvas, 25);

          // ⬛ LAYER 3: O BOX ESCURO DA LOGO (Igual ao container do seu app sô!)
          double boxLargura = 800; // Largura suficiente para abraçar a marca
          double boxAltura = 130; // Altura confortável para o texto de 110px
          double boxX = (larguraCanvas - boxLargura) / 2;
          double boxY = 120; // Posição vertical do box no papel

          ctx.fillStyle = '#1E1E26'; // Tom escuro original da marca
          // Desenha o retângulo do box
          ctx.fillRect(boxX, boxY, boxLargura, boxAltura);

          // 📝 LAYER 4: LOGO "aliuai" DENTRO DO BOX
          const String textoAli = 'ali';
          const String textoUai = 'uai';

          ctx.font = 'bold 95px "Poppins", "Helvetica Neue", sans-serif';
          ctx.textBaseline = 'middle';

          final num larguraAli = ctx.measureText(textoAli).width ?? 0;
          final num larguraUai = ctx.measureText(textoUai).width ?? 0;
          final num larguraTotalLogo = larguraAli + larguraUai;

          // Calcula o início do texto para centralizar milimetricamente DENTRO do box escuro
          double inicioX = (larguraCanvas - larguraTotalLogo) / 2;
          double logoY = boxY + (boxAltura / 2); // Centraliza verticalmente no meio do box

          // Pinta o "ali" de BRANCO SÓLIDO (Agora ele aparece perfeitamente sô!)
          ctx.fillStyle = '#FFFFFF';
          ctx.textAlign = 'left';
          ctx.fillText(textoAli, inicioX, logoY);

          // Pinta o "uai" de LARANJA SÓLIDO
          ctx.fillStyle = '#E65100';
          ctx.fillText(textoUai, inicioX + larguraAli, logoY);

          // ⚠️ RESET MÁGICO: Volta o alinhamento para o CENTRO para os textos externos
          ctx.textAlign = 'center';

          // 📋 LAYER 5: Textos do Corpo (Ajustados para cor escura sobre o papel branco)
          // Subtítulo Chamada de Ação
          ctx.fillStyle = '#65656A'; // Cinza escuro elegante para o papel branco
          ctx.font = '600 42px "Poppins", sans-serif';
          ctx.fillText('ESCANEIE O QR CODE & PEÇA AQUI', larguraCanvas / 2, 360);

          // Nome da Loja/Barraca em Laranja Destaque Gigante
          ctx.fillStyle = '#E65100';
          ctx.font = 'bold 76px "Poppins", sans-serif';
          ctx.fillText(nomeLoja.toUpperCase(), larguraCanvas / 2, 480);

          // Linha divisória fina e limpa
          ctx.strokeStyle = '#E0E0E6';
          ctx.lineWidth = 4;
          ctx.beginPath();
          ctx.moveTo(150, 560);
          ctx.lineTo(1050, 560);
          ctx.stroke();

          // 📱 LAYER 6: O QR Code centralizado (Não precisa de borda branca, o papel já é branco!)
          ctx.drawImageScaled(imgQr, larguraCanvas / 2 - 350, 640, 700, 700);

          // 📝 LAYER 7: Textos do Rodapé (Com link amigável e quebra de linha sô!)
          ctx.fillStyle = '#65656A';
          ctx.font = '500 34px "Poppins", sans-serif';
          ctx.fillText('Acesse o cardápio digital em:', larguraCanvas / 2, 1410);

          // 🔗 URL Estética e Amigável
          final String nomeLojaLimpo = nomeLoja.toLowerCase().replaceAll(' ', '');
          ctx.fillStyle = '#1E1E26';
          ctx.font = 'bold 44px "Poppins", sans-serif';
          ctx.fillText('aliuai.com.br/$nomeLojaLimpo', larguraCanvas / 2, 1480);

          // 📲 Chamada de Ação em duas linhas perfeitamente centralizadas e dentro da margem!
          ctx.fillStyle = '#E65100'; // O Laranja Solar de destaque sô
          ctx.font = 'bold 36px "Poppins", sans-serif'; // Diminuí um tiquinho para ficar elegante

          double linha1Y = 1610; // Altura da primeira linha
          double linha2Y = 1670; // Altura da segunda linha (60px de espaçamento)

          ctx.fillText('✨ APONTE A CÂMERA DO CELULAR', larguraCanvas / 2, linha1Y);
          ctx.fillText('  PARA O QR CODE ACIMA ✨', larguraCanvas / 2, linha2Y);

          // 📥 LAYER FINAL: Compila e faz o download automático do PNG sô!
          final String dataUrl = canvas.toDataUrl('image/png');
          final html.AnchorElement anchor = html.AnchorElement(href: dataUrl)
            ..setAttribute("download", "expositor_economico_${nomeLoja.toLowerCase().replaceAll(' ', '_')}.png")
            ..click();
        });
      }
    });
  }

  /// 🎨 Função que abre o pop-up com o QR Code centralizado e travado no tamanho certo sô!
  void _mostrarModalQrCode(BuildContext context) {
    final String urlLoja = 'https://aliuai.com.br/?loja=$lojaId';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    color: Color(0xFF1E1E26),
                    height: 60,
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          children: const [
                            TextSpan(
                              text: 'ali',
                              style: TextStyle(color: Colors.white), // Fica transparente sobre o fundo do app
                            ),
                            TextSpan(
                              text: 'uai',
                              style: TextStyle(color: Color(0xFFE65100)), // Seu Laranja Efí oficial!
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: Color(0xFFE65100), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'QR Code - $nomeLoja',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 🔥 RESOLUÇÃO DO ERRO: Envelopamos tudo em um SizedBox com largura fixa
        content: SizedBox(
          width: 320, // Garante um tamanho padrão seguro para o modal não estourar
          child: Column(
            mainAxisSize: MainAxisSize.min, // Faz o modal encolher verticalmente ao máximo
            children: [
              const Text(
                'Aponte a câmera do celular para testar ou clique no botão abaixo para baixar a imagem de impressão sô!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // O Quadrado do QR Code isolado dentro do pop-up
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: QrImageView(
                  data: urlLoja,
                  version: QrVersions.auto,
                  size: 200.0, // Tamanho do QR Code interno
                  gapless: true,
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: urlLoja));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Link copiado para a área de transferência! 📋'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          urlLoja,
                          style: const TextStyle(color: Colors.black54, fontSize: 12, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E26),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Baixar PNG', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _baixarQrCode,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ehCelular = MediaQuery.of(context).size.width < 800;

    // Retorna apenas o botão responsivo que chama o modal sô!
    return Center(
      child: SizedBox(
        width: ehCelular ? double.infinity : 350,
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE65100), width: 1.5),
            foregroundColor: const Color(0xFFE65100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.qr_code_2_rounded, size: 22),
          label: const Text('Visualizar QR Code de Vendas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          onPressed: () => _mostrarModalQrCode(context),
        ),
      ),
    );
  }
}
