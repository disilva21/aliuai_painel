import 'package:aliuai_painel/criar_pedido_manual_modal.dart';
import 'package:aliuai_painel/util/servico_impressao_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

@JS('window.open')
external JSObject? _windowOpen(JSString url, JSString name, JSString features);

class PedidosScreen extends StatelessWidget {
  final String lojaId;

  const PedidosScreen({super.key, required this.lojaId});

  // 🎨 Mapa de cores e textos amigáveis para cada status
  Map<String, dynamic> _configurarStatus(String status) {
    switch (status) {
      case 'pendente':
        return {'texto': 'Pendente ⏳', 'cor': Colors.orange[800], 'proximo': 'aceito', 'botao': 'Aceitar Pedido'};
      case 'aceito':
        return {'texto': 'Em Preparo 🍳', 'cor': Colors.blue[800], 'proximo': 'saiu_para_entrega', 'botao': 'Saiu para Entrega / Pronto'};
      case 'saiu_para_entrega':
        return {'texto': 'Em Rota 🛵', 'cor': Colors.purple[800], 'proximo': 'entregue', 'botao': 'Finalizar (Entregue)'};
      case 'entregue':
        return {'texto': 'Entregue ✅', 'cor': Colors.green[800], 'proximo': null, 'botao': ''};
      default:
        return {'texto': 'Cancelado 🛑', 'cor': Colors.red[800], 'proximo': null, 'botao': ''};
    }
  }

  // 🔄 Função para avançar o status do pedido no Firestore
  Future<void> _atualizarStatus(String pedidoId, String novoStatus) async {
    await FirebaseFirestore.instance.collection('pedidos').doc(pedidoId).update({'status': novoStatus});
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Captura a largura para orquestrar a responsividade da esteira de pedidos sô!
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelularGeral = larguraTela < 800;
    final _servicoImpressao = ServicoImpressao();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Pedidos em Tempo Real', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.black87,
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F5),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E26), // Escuro institucional do AliUai
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
            label: const Text('Lançar Venda Balcão', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: () => _abrirModalPedidoManual(context),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('estabelecimento_id', isEqualTo: lojaId)
            .where('origem', isNotEqualTo: 'fiado')
            .orderBy('origem')
            .orderBy('criado_em', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text('Erro ao carregar pedidos'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text('Nenhum pedido recebido ainda. Quando chegar, vai aparecer aqui! 🏪', textAlign: TextAlign.center),
              ),
            );
          }

          final pedidosDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pedidosDocs.length,
            itemBuilder: (context, index) {
              final pedidoId = pedidosDocs[index].id;
              final pedido = pedidosDocs[index].data() as Map<String, dynamic>;

              final String status = pedido['status'] ?? 'pendente';
              final double total = (pedido['total'] ?? 0.0).toDouble();
              final List<dynamic> itens = pedido['itens'] ?? [];

              final Timestamp? timestamp = pedido['criado_em'];
              final String horaFormatada = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '--:--';

              final config = _configurarStatus(status);

              // Componente do Selo de Status sô
              final Widget seloStatus = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: config['cor']!.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  config['texto'],
                  style: TextStyle(color: config['cor'], fontWeight: FontWeight.bold, fontSize: 12),
                ),
              );

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ExpansionTile(
                  // No mobile tiramos o trailing fixo para embutir no cabeçalho sô!
                  trailing: ehCelularGeral ? const Icon(Icons.expand_more) : seloStatus,
                  title: ehCelularGeral
                      ? Column(
                          // 📱 CABEÇALHO MOBILE: Empilhado e contido sô!
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pedido: #${pedido['pedido']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                seloStatus,
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Cliente: ${pedido['nome_cliente']}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                            Text('Celular: ${pedido['celular']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        )
                      : Row(
                          // 🖥️ CABEÇALHO WEB: Três colunas limpas lado a lado sô!
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('Pedido: #${pedido['pedido']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            Expanded(
                              child: Text('Cliente: ${pedido['nome_cliente']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            Expanded(
                              child: Text('${pedido['celular']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ehCelularGeral
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('⏱️ Rec. às $horaFormatada', style: const TextStyle(fontSize: 13)),
                              Text(
                                'Total: R\$ ${total.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Text('Recebido às $horaFormatada', style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 20),
                              Text('Total: R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📋 ITENS DO PEDIDO:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 8),

                          ...itens.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('${item['quantidade']}x ${item['nome_produto']}', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                  ),
                                  Text('R\$ ${((item['preco_unitario'] ?? 0) * (item['quantidade'] ?? 1)).toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Taxa de Entrega:', style: TextStyle(fontSize: 14)),
                              Text('R\$ ${((pedido['taxa_entrega'] ?? 0)).toStringAsFixed(2)}'),
                            ],
                          ),

                          const Divider(),
                          const SizedBox(height: 8),
                          Text('📍 Endereço: ${pedido['endereco']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 24),

                          // =======================================================================
                          // BOTÕES DE AÇÃO RESPONSIVOS: Acabou a briga de espaço sô!
                          // =======================================================================
                          ehCelularGeral
                              ? Column(
                                  // 📱 AÇÕES NO MOBILE: Empilhados verticalmente sô!
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (config['proximo'] != null) ...[
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: config['cor'],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _atualizarStatus(pedidoId, config['proximo']),
                                        child: Text(config['botao'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (status != 'entregue' && status != 'cancelado')
                                          TextButton.icon(
                                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                            icon: const Icon(Icons.cancel_outlined, size: 18),
                                            onPressed: () => _atualizarStatus(pedidoId, 'cancelado'),
                                            label: const Text('Recusar Pedido'),
                                          ),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFE65100),
                                            side: const BorderSide(color: Color(0xFFE65100)),
                                          ),
                                          icon: const Icon(Icons.print_rounded, size: 18),
                                          label: const Text('Imprimir'),
                                          onPressed: () async {
                                            await _servicoImpressao.imprimirPedidoNativo(pedido);

                                            // imprimirCupomWeb();

                                            // imprimirPedidoWeb(
                                            //   estabelecimento: pedido['estabelecimento_id'],
                                            //   numeroPedido: pedido['pedido'],
                                            //   nomeCliente: pedido['nome_cliente'],
                                            //   tipoEntrega: pedido['endereco'],
                                            //   formaPagamento: pedido['forma_pagamento'],
                                            //   itens: pedido['itens'],
                                            //   total: total,
                                            // );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Row(
                                  // 🖥️ AÇÕES NA WEB: Mantém a linha limpa com spacers sô!
                                  children: [
                                    if (status != 'entregue' && status != 'cancelado')
                                      TextButton(
                                        onPressed: () => _atualizarStatus(pedidoId, 'cancelado'),
                                        child: const Text('Recusar/Cancelar', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.print_rounded, color: Color(0xFFE65100)),
                                      tooltip: 'Imprimir Cupom',
                                      onPressed: () async {
                                        final Map<String, dynamic> pedidoParaImprimir = Map<String, dynamic>.from(pedido);

                                        // 2. Cria um atalho fora do contexto assíncrono para o SnackBar não chiar uai
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Enviando dados para a POS58... 🌾'), duration: Duration(seconds: 1)));

                                        try {
                                          // 3. Passa a variável local limpa para o serviço de impressão sô!
                                          await _servicoImpressao.imprimirPedidoNativo(pedidoParaImprimir);
                                          // imprimirCupomWeb();
                                        } catch (e) {
                                          print("Erro na fiação de impressão sô: $e");
                                        }
                                        await _servicoImpressao.imprimirPedidoNativo(pedido);

                                        // imprimirPedidoWeb(
                                        //   estabelecimento: pedido['estabelecimento_id'],
                                        //   numeroPedido: pedido['pedido'],
                                        //   nomeCliente: pedido['nome_cliente'],
                                        //   tipoEntrega: pedido['endereco'],
                                        //   formaPagamento: pedido['forma_pagamento'],
                                        //   itens: pedido['itens'],
                                        //   total: total,
                                        // );
                                      },
                                    ),
                                    const Spacer(),
                                    if (config['proximo'] != null)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: config['cor'],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _atualizarStatus(pedidoId, config['proximo']),
                                        child: Text(config['botao']),
                                      ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _abrirModalPedidoManual(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🚀 ESSENCIAL: Faz o modal subir e não ser coberto pelo teclado uai!
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        // widget.lojaId deve ser a variável que você já recebe na sua tela principal sô!
        return CriarPedidoManualModal(lojaId: lojaId, cidadeId: '');
      },
    );
  }

  void imprimirCupomWeb() {
    final String conteudoCupom = '''
    <html>
      <head>
        <style>
          @page { size: 58mm auto; margin: 0; }
          body { 
            width: 48mm; 
            margin: 5mm; 
            font-family: 'Courier New', Courier, monospace; 
            font-size: 12px; 
          }
          .centralizado { text-align: center; font-weight: bold; }
          .linha { border-bottom: 1px dashed #000; margin: 5px 0; }
          .item { display: flex; justify-content: space-between; }
        </style>
      </head>
      <body>
        <div class="centralizado">*** ALIUAI DELIVERY ***</div>
        <div class="centralizado">Pedido: #1024</div>
        <div class="linha"></div>
        <div class="item"><span>1x X-Tudo</span> <span>R\$ 25,00</span></div>
        <div class="item"><span>1x Coca Lata</span> <span>R\$ 6,00</span></div>
        <div class="linha"></div>
        <div class="item" style="font-weight: bold;"><span>Total:</span> <span>R\$ 31,00</span></div>
        <br><br>

        <!-- 🚀 O SEGREDO DO TRATOR TÁ AQUI SÔ: -->
        <!-- O próprio HTML se encarrega de disparar o print e fechar a janela assim que carregar uai! -->
        <script>
          window.onload = function() {
            window.print();
            // Dá um tempinho pequeno pro lojista clicar e fecha a aba sô
            setTimeout(function() { window.close(); }, 500);
          };
        </script>
      </body>
    </html>
  ''';

    // Abre a janela limpinha uai
    dynamic janela = _windowOpen(''.toJS, 'ImpressaoAliUai'.toJS, 'width=400,height=600'.toJS);

    if (janela != null) {
      // Injeta o HTML com o script embutido sô!
      janela.document.body.innerHTML = conteudoCupom;
    }
  }

  void imprimirPedidoWeb({
    required String estabelecimento,
    required String numeroPedido,
    required String nomeCliente,
    required String tipoEntrega,
    required String formaPagamento,
    required List<dynamic> itens,
    required double total,
  }) {
    // 🚀 Mudamos o CSS para ser o mais rústico possível pro driver genérico ler puro sô!
    String conteudoHtml =
        '''
    <html>
      <head>
        <style>
          @page { size: auto; margin: 0mm; }
          body { 
            font-family: 'Courier New', Courier, monospace;
            width: 44mm;
            margin: 1mm;
            font-size: 11px;
            color: #000;
          }
          .centralizado { text-align: center; }
          .negrito { font-weight: bold; }
          /* 🚀 Tabela pura para travar as linhas uma embaixo da outra sô */
          table { width: 100%; border-collapse: collapse; margin: 0; padding: 0; }
          td { padding: 1px 0; margin: 0; vertical-align: top; }
        </style>
      </head>
      <body>
        <div class="centralizado negrito" style="font-size: 13px;">🔥 $estabelecimento 🔥</div>
        <div class="centralizado">Pedido: #$numeroPedido</div>
        <div class="centralizado">--------------------------------</div>
        
        <table>
          <tr><td class="negrito" style="width: 30%;">Cliente:</td><td>$nomeCliente</td></tr>
          <tr><td class="negrito">Entrega:</td><td>$tipoEntrega</td></tr>
          <tr><td class="negrito">Pagam.:</td><td>$formaPagamento</td></tr>
        </table>
        
        <div class="centralizado">--------------------------------</div>
        <div class="negrito">ITENS DO PEDIDO:</div>
        
        <table>
    ''';

    for (var itemDynamic in itens) {
      final item = itemDynamic as Map<String, dynamic>;
      final int qtd = item['quantidade'] ?? 1;
      final String nome = item['nome_produto'] ?? 'Produto';
      final double precoOriginal = (item['preco_unitario'] ?? 0.0).toDouble();
      final String precoFormatado = precoOriginal.toStringAsFixed(2).replaceAll('.', ',');

      // 🚀 Cada item vira uma linha física da tabela uai
      conteudoHtml +=
          '''
          <tr>
            <td style="width: 75%;">${qtd}x $nome</td>
            <td style="width: 25%; text-align: right;">R\$$precoFormatado</td>
          </tr>
          ''';
    }

    conteudoHtml +=
        '''
        </table>
        
        <div class="centralizado">--------------------------------</div>
        
        <table>
          <tr class="negrito" style="font-size: 12px;">
            <td style="width: 70%;">TOTAL:</td>
            <td style="width: 30%; text-align: right;">R\$${total.toStringAsFixed(2).replaceAll('.', ',')}</td>
          </tr>
        </table>
        
        <div class="centralizado">--------------------------------</div>
        <div class="centralizado">Obrigado pela preferência! 🤠</div>
        <br><br>
      </body>
    </html>
    ''';

    final janelaImpressao = web.window.open('', '_blank', 'width=400,height=600');
    if (janelaImpressao != null) {
      janelaImpressao.document.write(conteudoHtml.toJS);
      janelaImpressao.document.close();

      web.window.setTimeout(
        () {
          janelaImpressao.print();
          janelaImpressao.close();
        }.toJS,
        500.toJS,
      );
    }
  }
}
