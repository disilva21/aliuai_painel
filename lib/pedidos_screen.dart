import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos em Tempo Real 🔔', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.black87,
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').where('estabelecimento_id', isEqualTo: lojaId).orderBy('criado_em', descending: true).snapshots(),
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
                                          onPressed: () {
                                            imprimirPedidoWeb(
                                              estabelecimento: pedido['estabelecimento_id'],
                                              numeroPedido: pedido['pedido'],
                                              nomeCliente: pedido['nome_cliente'],
                                              tipoEntrega: pedido['endereco'],
                                              formaPagamento: pedido['forma_pagamento'],
                                              itens: pedido['itens'],
                                              total: total,
                                            );
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
                                      onPressed: () {
                                        imprimirPedidoWeb(
                                          estabelecimento: pedido['estabelecimento_id'],
                                          numeroPedido: pedido['pedido'],
                                          nomeCliente: pedido['nome_cliente'],
                                          tipoEntrega: pedido['endereco'],
                                          formaPagamento: pedido['forma_pagamento'],
                                          itens: pedido['itens'],
                                          total: total,
                                        );
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

  void imprimirPedidoWeb({
    required String estabelecimento,
    required String numeroPedido,
    required String nomeCliente,
    required String tipoEntrega,
    required String formaPagamento,
    required List<dynamic> itens,
    required double total,
  }) {
    String conteudoHtml =
        '''
    <html>
      <head>
        <style>
          @page { size: auto; margin: 0mm; }
          body { 
            font-family: 'Courier New', Courier, monospace;
            width: 280px;
            margin: 10px;
            font-size: 12px;
            color: #000;
          }
          .centralizado { text-align: center; }
          .linha { border-bottom: 1px dashed #000; margin: 8px 0; }
          .item { display: flex; justify-content: space-between; }
          .negrito { font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="centralizado negrito" style="font-size: 16px;">🔥 PAINEL ALIUAI 🔥</div>
        <div class="centralizado">Pedido: #$numeroPedido</div>
        <div class="linha"></div>
        <div><span class="negrito">Cliente:</span> $nomeCliente</div>
        <div><span class="negrito">Operação:</span> $tipoEntrega</div>
        <div><span class="negrito">Pagamento:</span> $formaPagamento</div>
        <div class="linha"></div>
        <div class="negrito">ITENS DO PEDIDO:</div>
    ''';

    for (var itemDynamic in itens) {
      final item = itemDynamic as Map<String, dynamic>;
      final int qtd = item['quantidade'] ?? 1;
      final String nome = item['nome_produto'] ?? 'Produto';
      final double precoOriginal = (item['preco_unitario'] ?? 0.0).toDouble();
      final String precoFormatado = precoOriginal.toStringAsFixed(2).replaceAll('.', ',');

      conteudoHtml +=
          '''
      <div class="item">
        <span>${qtd}x $nome</span>
        <span>R\$ $precoFormatado</span>
      </div>
      ''';
    }

    conteudoHtml +=
        '''
        <div class="linha"></div>
        <div class="item negrito" style="font-size: 14px;">
          <span>TOTAL:</span>
          <span>R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}</span>
        </div>
        <br>
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
