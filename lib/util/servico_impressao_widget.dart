import 'dart:html' as html; // 📍 Essencial para rodar direto no Chrome sô!
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ServicoImpressao {
  /// 🖨️ MÁGICA DA IMPRESÃO VIA NAVEGADOR WEB (TEXTO PURO COMPACTO)
  Future<void> imprimirPedidoNativo(Map<String, dynamic> pedido) async {
    if (!kIsWeb) {
      print("Essa fiação foi feita para rodar direto no Google Chrome sô!");
      return;
    }
    String nomeEstabelecimento = '';
    final docLoja = await FirebaseFirestore.instance.collection('estabelecimentos').doc(pedido['estabelecimento_id']).get();
    if (docLoja.exists) {
      final dados = docLoja.data() as Map<String, dynamic>;
      nomeEstabelecimento = dados['nome'] ?? '';
    }

    // 📋 Extrai os dados do pedido uai!
    String codigo = pedido['pedido']?.toString() ?? '000000';
    String origem = (pedido['origem'] ?? 'balcao').toString().toUpperCase();
    String clienteNome = pedido['nome_cliente'] ?? 'Cliente Casual';
    String clienteCelular = pedido['forma_pagamento'] ?? 'Sem celular';
    double total = double.tryParse(pedido['total'].toString()) ?? 0.0;
    List<dynamic> itens = pedido['itens'] ?? [];

    DateTime agora = DateTime.now();

    // 📐 Formata na marra colocando o zero na esquerda se o número for menor que 10
    String dia = agora.day.toString().padLeft(2, '0');
    String mes = agora.month.toString().padLeft(2, '0');
    String ano = agora.year.toString();

    String dataFormatada = "$dia/$mes/$ano";

    // =========================================================================
    // 🎯 CÁLCULO DE CENTRALIZAÇÃO DINÂMICA DO ESTABELECIMENTO SÔ
    // =========================================================================
    String estabelecimentoCentralizado = nomeEstabelecimento;
    if (nomeEstabelecimento.length < 32) {
      int espacosEsquerda = (32 - nomeEstabelecimento.length) ~/ 2;
      estabelecimentoCentralizado = ("&nbsp;" * espacosEsquerda) + nomeEstabelecimento;
    }

    // =========================================================================
    // 🚀 MONTAGEM DOS ITENS USANDO ESPAÇOS FÍSICOS
    // =========================================================================
    StringBuffer itensHtml = StringBuffer();
    for (var item in itens) {
      String prodNome = item['nome_produto'] ?? 'Produto';
      String qtd = (item['quantidade'] ?? 1).toString();
      double precoUn = double.tryParse(item['preco_unitario'].toString()) ?? 0.0;
      double subTotal = precoUn * double.tryParse(qtd)!;

      String linhaValores = "$qtd x R\$ ${precoUn.toStringAsFixed(2)}";
      String linhaSubtotal = "R\$ ${subTotal.toStringAsFixed(2)}";

      int espacosNecessarios = 32 - (linhaValores.length + linhaSubtotal.length);
      if (espacosNecessarios < 1) espacosNecessarios = 1;
      String espacosEmBranco = "&nbsp;" * espacosNecessarios;

      itensHtml.write('''
        $prodNome<br>
        $linhaValores$espacosEmBranco$linhaSubtotal<br>
        <br>
      ''');
    }

    // =========================================================================
    // 📐 ALINHAMENTO DA DATA (32 caracteres totais sô)
    // =========================================================================
    int espacosData = 32 - (6 + dataFormatada.length);
    if (espacosData < 1) espacosData = 1;
    String espacosEmBrancoData = "&nbsp;" * espacosData;

    final String conteudoCupom =
        '''
        <html>
          <head>
            <meta charset="UTF-8">
            <style>
              @page { size: 58mm auto; margin: 0; }
              body { 
                width: 44mm; 
                font-family: 'Courier New', Courier, monospace; 
                font-size: 11px; 
                font-weight: normal;
                color: #000000; 
                margin: 0px;
                padding: 0px;
                white-space: nowrap; 
              }
            </style>
          </head>
          <body>
            $estabelecimentoCentralizado<br><br>           
            Pedido: $codigo<br>           
            --------------------------------<br>
            Data: $espacosEmBrancoData$dataFormatada<br>            
            --------------------------------<br>
            Cliente: $clienteNome<br>
            ${clienteCelular != 'Sem celular' ? 'Pagto: $clienteCelular<br>' : ''}
            --------------------------------<br>
            <br>Itens:<br>
            <br>
            
            $itensHtml
            
            --------------------------------<br>
            TOTAL:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;R\$ ${total.toStringAsFixed(2)}<br>
            --------------------------------<br>
            &nbsp;&nbsp;&nbsp;Obrigado pela preferência!<br>
            &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;=== ALIUAI ===
            <br><br><br>
            <script>
              window.onload = function() {
                window.print();
                setTimeout(function() { window.close(); }, 500);
              };
            </script>
          </body>
        </html>
      ''';

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final blob = html.Blob([conteudoCupom], 'text/html;charset=utf-8');
    final String urlUrl = html.Url.createObjectUrlFromBlob(blob);

    final html.WindowBase? janelaImpressao = html.window.open(urlUrl, 'Imprimir_$timestamp', 'width=350,height=600');

    if (janelaImpressao == null) {
      print("A porteira do Chrome barrou os pop-ups uai!");
    }

    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(urlUrl);
    });
  }
}
