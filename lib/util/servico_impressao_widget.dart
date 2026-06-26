import 'dart:html' as html; // 📍 Essencial para rodar direto no Chrome sô!
import 'package:flutter/foundation.dart';

class ServicoImpressao {
  /// 🖨️ MÁGICA DA IMPRESÃO VIA NAVEGADOR WEB (USB / SISTEMA)
  Future<void> imprimirPedidoNativo(Map<String, dynamic> pedido) async {
    // 📱 Trava invertida: se por acaso rodar no celular, avisa o caboclo uai
    if (!kIsWeb) {
      print("Essa fiação foi feita para rodar direto no Google Chrome sô!");
      return;
    }

    // 📋 Extrai e blinda os dados do pedido (reparando as tipagens uai!)

    String codigo = pedido['pedido']?.toString() ?? '000000';

    String origem = (pedido['origem'] ?? 'balcao').toString().toUpperCase();

    String clienteNome = pedido['nome_cliente'] ?? 'Cliente Casual';

    String clienteCelular = pedido['forma_pagamento'] ?? 'Sem celular';

    double total = double.tryParse(pedido['total'].toString()) ?? 0.0;

    List<dynamic> itens = pedido['itens'] ?? [];

    // =========================================================================
    // 📐 MONTAGEM DO CUPOM EM HTML/CSS RIGOROSO PARA 58MM SÔ!
    // Usamos fontes nativas do sistema (Arial/Monospace) que a impressora lê liso.
    // =========================================================================

    StringBuffer itensHtml = StringBuffer();
    for (var item in itens) {
      String prodNome = item['nome'] ?? 'Produto';
      String qtd = (item['quantidade'] ?? 1).toString();
      double precoUn = double.tryParse(item['preco_unitario'].toString()) ?? 0.0;
      double subTotal = precoUn * double.tryParse(qtd)!;

      itensHtml.write('''
          <div style="margin-bottom: 5px;">
            <div style="font-weight: bold;">$prodNome</div>
            <div style="display: flex; justify-content: space-between; font-size: 11px;">
              <span>  $qtd x R\$ ${precoUn.toStringAsFixed(2)}</span>
              <span>R\$ ${subTotal.toStringAsFixed(2)}</span>
            </div>
          </div>
        ''');
    }

    final String conteudoCupom =
        '''
        <html>
          <head>
           <style>
  @page { 
    size: 58mm auto; 
    margin: 0; 
  }
  body { 
    width: 46mm; 
    /* 1. Mudamos para Arial/Helvetica: fontes sem serifa ficam muito mais grossas e nítidas na POS58 que a Courier sô! */
    font-family: 'Arial Black', 'Arial', sans-serif; 
    font-size: 12px; 
    /* 2. Forçamos o preto absoluto e adicionamos um contorno leve de texto para engrossar a letra uai! */
    color: #000000; 
    -webkit-text-stroke: 0.3px #000000; /* 🔥 Engrossa a fiação da letra na marra! */
    font-weight: 900; /* Força o negrito máximo de fábrica */
    margin: 5px;
    padding: 0;
  }
  .centralizado { 
    text-align: center; 
    font-weight: bold;
  }
  /* 3. Linha preta contínua e mais grossa (Dashed/Serrilhado costuma borrar em POS58 sô) */
  .linha { 
    border-top: 2px solid #000000; 
    margin: 8px 0; 
  }
  .flex-space { 
    display: flex; 
    justify-content: space-between; 
    font-weight: bold;
  }
</style>
          </head>
          <body>
            <div class="centralizado" style="font-size: 12px; font-weight: bold;">=== ALIUAI ===</div>
            <div class="centralizado" style="font-weight: bold;">PEDIDO: $codigo</div>
            <div class="centralizado" style="font-size: 11px;">ORIGEM: $origem</div>
            <div class="flex-space" style="font-size: 11px;">
              <span>DATA:</span>
              <span>HOJE SÔ</span>
            </div>
            
            <div class="linha"></div>
            
            <div><strong>CLIENTE:</strong> $clienteNome</div>
            ${clienteCelular != 'Sem celular' ? '<div><strong>ZAP:</strong> $clienteCelular</div>' : ''}
            
            <div class="linha"></div>
            
            <div style="margin-bottom: 6px;"><strong>ITENS DO PEDIDO:</strong></div>
            $itensHtml
            
            <div class="linha"></div>
            
            <div class="flex-space" style="font-size: 9px;">
              <span>TOTAL:</span>
              <span>R\$ ${total.toStringAsFixed(2)}</span>
            </div>
            
            <div class="linha"></div>
            <div class="centralizado" style="font-size: 8px;">Obrigado pela preferência! 🌾</div>
            <div class="centralizado" style="font-size: 8px; margin-top: 2px;">AliUai - O Trator do Comércio</div>
            
            <div style="height: 30px;"></div> <script>
              // 📑 Executa a impressão assim que a janelinha abrir sô!
              window.onload = function() {
                window.print();
                setTimeout(function() { window.close(); }, 500);
              };
            </script>
          </body>
        </html>
      ''';

    // =========================================================================
    // 🚀 DISPARANDO O CONTEÚDO DIRETO NA JANELA DO CHROME UAI
    // =========================================================================
    // =========================================================================
    // 🚀 DISPARANDO O CONTEÚDO USANDO BLOB (BLINDADO CONTRA ERROS DE APIS SÔ!)
    // =========================================================================
    // 1. Cria um arquivo HTML virtual em memória com o cupom uai
    final blob = html.Blob([conteudoCupom], 'text/html');
    final String urlUrl = html.Url.createObjectUrlFromBlob(blob);

    // 2. Manda o Chrome abrir direto essa URL do cupom numa nova aba sô!
    final html.WindowBase? janelaImpressao = html.window.open(urlUrl, 'Imprimir Pedido AliUai', 'width=350,height=600');

    if (janelaImpressao == null) {
      print("A porteira do Chrome barrou o pop-up da impressão sô! Ative os pop-ups no navegador.");
    }

    // 3. Limpa a memória depois de 5 segundos para o trator não atolar sô
    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(urlUrl);
    });
  }
}
