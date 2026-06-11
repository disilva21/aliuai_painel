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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos em Tempo Real 🔔', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.black87,
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F5),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 📡 ESCUTA EM TEMPO REAL: Filtra os pedidos dessa loja, dos mais novos para os mais velhos
        stream: FirebaseFirestore.instance.collection('pedidos').where('estabelecimento_id', isEqualTo: lojaId).orderBy('criado_em', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error); // Loga o erro para debug
            return Center(child: Text('Erro ao carregar pedidos'));
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

              // Trata a data de criação
              final Timestamp? timestamp = pedido['criado_em'];
              final String horaFormatada = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '--:--';

              final config = _configurarStatus(status);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ExpansionTile(
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: config['cor']!.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      config['texto'],
                      style: TextStyle(color: config['cor'], fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  title: Row(
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
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Text('Recebido às $horaFormatada', style: const TextStyle(fontSize: 16)),
                        SizedBox(width: 20),
                        Text('Total: R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
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

                          // Lista os produtos de dentro do pedido
                          ...itens.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item['quantidade']}x ${item['nome_produto']}', style: const TextStyle(fontSize: 14)),
                                  Text('R\$ ${((item['preco_unitario'] ?? 0) * (item['quantidade'] ?? 1)).toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Taxa de Entrega:', style: const TextStyle(fontSize: 14)),
                              Text('R\$ ${((pedido['taxa_entrega'] ?? 0)).toStringAsFixed(2)}'),
                            ],
                          ),

                          const Divider(),
                          const SizedBox(height: 8),
                          Text('📍 Endereço: ${pedido['endereco']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          // Text('📞 WhatsApp: ${pedido['telefone_cliente']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 20),

                          // =======================================================================
                          // BOTÕES DE AÇÃO: Controlam a esteira de status do pedido
                          // =======================================================================
                          Row(
                            children: [
                              // Botão de Cancelar (Apenas se não foi entregue ou já cancelado)
                              if (status != 'entregue' && status != 'cancelado')
                                TextButton(
                                  onPressed: () => _atualizarStatus(pedidoId, 'cancelado'),
                                  child: const Text('Recusar/Cancelar', style: TextStyle(color: Colors.redAccent)),
                                ),
                              const Spacer(),

                              IconButton(
                                icon: const Icon(Icons.print_rounded, color: Color(0xFFE65100)),
                                onPressed: () {
                                  // Dispara a impressão que monta o cupom na hora!
                                  imprimirPedidoWeb(
                                    estabelecimento: pedido['estabelecimento_id'],
                                    numeroPedido: pedido['pedido'],
                                    nomeCliente: pedido['nome_cliente'],
                                    tipoEntrega: pedido['endereco'],
                                    formaPagamento: pedido['forma_pagamento'],
                                    itens: pedido['itens'],
                                    // itens:
                                    // [
                                    //   {'qtd': 2, 'nome': 'Pastel de Carne', 'preco': '14,00'},
                                    //   {'qtd': 1, 'nome': 'Coca-Cola Lata', 'preco': '6,00'},
                                    // ],
                                    total: total,
                                  );
                                },
                              ),
                              const Spacer(),
                              // Botão Dinâmico de Avanço
                              if (config['proximo'] != null)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: config['cor'],
                                    foregroundColor: Colors.white,
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
    // 📝 1. Montamos a estrutura do cupom formatada para bobina térmica
    String conteudoHtml =
        '''
    <html>
      <head>
        <style>
          @page { size: auto; margin: 0mm; }
          body { 
            font-family: 'Courier New', Courier, monospace; /* Fonte estilo cupom sô */
            width: 280px; /* Largura ideal para bobinas de 80mm */
            margin: 10px;
            font-size: 12px;
            color: #000;
          }
          .centralizado { text-align: center; }
          .linha { border-bottom: 1px dashed #000; margin: 8px 0; }
          .item { display: flex; main-axis-alignment: space-between; }
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

    // Loop para listar os produtos do carrinho
    for (var itemDynamic in itens) {
      // Forçamos o Dart a entender o item como um mapa de chave e valor
      final item = itemDynamic as Map<String, dynamic>;

      // Buscamos os campos exatamente como você salvou no banco (ajuste os nomes se necessário sô!)
      final int qtd = item['quantidade'] ?? 1;
      final String nome = item['nome_produto'] ?? 'Produto';

      // Tratamento para o preço não quebrar se vier double, int ou String sô
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

    // 🚀 2. A MÁGICA WEB: Cria uma janela oculta e manda imprimir direto sô!
    final janelaImpressao = web.window.open('', '_blank', 'width=400,height=600');
    if (janelaImpressao != null) {
      janelaImpressao.document.write(conteudoHtml.toJS);
      janelaImpressao.document.close();

      // Pequeno delay para garantir que o HTML carregou na janelinha antes de abrir o print
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
