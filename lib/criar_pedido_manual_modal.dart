import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CriarPedidoManualModal extends StatefulWidget {
  final String lojaId;
  final String cidadeId;

  const CriarPedidoManualModal({super.key, required this.lojaId, required this.cidadeId});

  @override
  State<CriarPedidoManualModal> createState() => _CriarPedidoManualModalState();
}

class _CriarPedidoManualModalState extends State<CriarPedidoManualModal> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nomeClienteController = TextEditingController();
  final _celularClienteController = TextEditingController();
  final _taxaEntregaController = TextEditingController(text: "0.00");
  final _enderecoController = TextEditingController();
  final _observacaoController = TextEditingController();

  final _maskCelular = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  // Estados do formulário sô!
  String _formaPagamento = 'Dinheiro';
  String _statusPedido = 'entregue'; // Padrão: Concluído (Balcão)

  // 🛒 Estrutura de Carrinho de Itens sô!
  List<Map<String, dynamic>> _itensCarrinho = [];
  Map<String, dynamic>? _produtoSelecionado;
  int _quantidade = 1;
  double _precoUnitario = 0.0;

  double _taxaEntrega = 0.0;
  bool _salvando = false;

  @override
  void dispose() {
    _celularClienteController.dispose();
    _nomeClienteController.dispose();
    _taxaEntregaController.dispose();
    _enderecoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  // 💰 Cálculo matemático dinâmico: Varre a lista de itens + Taxa sô!
  double get _valorTotal {
    double subtotal = 0.0;
    for (var item in _itensCarrinho) {
      subtotal += (item['preco_unitario'] * item['quantidade']);
    }
    return subtotal + _taxaEntrega;
  }

  // ➕ Coloca o produto selecionado na lista temporária do pedido
  void _adicionarItemAoCarrinho() {
    if (_produtoSelecionado == null) return;

    setState(() {
      // Se o lojista adicionar o mesmo produto de novo, só atualiza a quantidade sô!
      int indexExistente = _itensCarrinho.indexWhere((item) => item['produto_id'] == _produtoSelecionado!['id']);

      if (indexExistente != -1) {
        _itensCarrinho[indexExistente]['quantidade'] += _quantidade;
      } else {
        _itensCarrinho.add({'produto_id': _produtoSelecionado!['id'], 'nome_produto': _produtoSelecionado!['nome'], 'quantidade': _quantidade, 'preco_unitario': _precoUnitario});
      }

      // Reseta a quantidade para o próximo produto uai
      _quantidade = 1;
    });
  }

  void _salvarPedidoManual() async {
    if (_itensCarrinho.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um produto sô! 🛒'), backgroundColor: Colors.redAccent));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final int milissegundos = DateTime.now().millisecondsSinceEpoch;
    final int numeroDoPedidoData = milissegundos % 1000000;
    final String? usuarioUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      // 📡 Injeta o pedido mantendo suas chaves originais do banco sô!
      await _firestore.collection('pedidos').add({
        'estabelecimento_id': widget.lojaId,
        'nome_cliente': _nomeClienteController.text.trim().isEmpty ? 'Cliente Balcão' : _nomeClienteController.text.trim(),
        'celular': _celularClienteController.text,
        'origem': 'balcao',
        'uid': usuarioUid ?? 'admin_manual',
        'cidade_id': widget.cidadeId,
        'pedido': numeroDoPedidoData.toString(),
        'status': _statusPedido,
        'forma_pagamento': _formaPagamento,
        'criado_em': FieldValue.serverTimestamp(),
        'taxa_entrega': _taxaEntrega,
        'total': _valorTotal,
        'endereco': _statusPedido == 'entregue' ? '' : _enderecoController.text.trim(),
        'observacao': _observacaoController.text.trim(),
        'itens': _itensCarrinho, // 🚀 Salva a array inteira com todos os produtos!
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido lançado com sucesso! 💸'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar o pedido sô: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool ehEntrega = _statusPedido != 'entregue';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '➕ Lançar Venda Manual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // 👤 Nome do Cliente (Opcional)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3, // Ocupa 3 partes do espaço pro nome caber bem
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nome do Cliente (Opcional):',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nomeClienteController,
                          decoration: InputDecoration(
                            hintText: 'Ex: João do Telefone',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12), // Espaço entre os campos sô
                  Expanded(
                    flex: 2, // Ocupa 2 partes do espaço, ideal para o número do celular uai
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Celular / Zap:',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _celularClienteController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_maskCelular], // 🚀 A mágica acontece aqui sô!
                          decoration: InputDecoration(
                            hintText: '(35) 99999-9999',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 📦 1. Seletor de Produtos direto do Firestore
              const Text(
                'Selecione o Produto:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
              ),
              const SizedBox(height: 6),
              FutureBuilder<QuerySnapshot>(
                future: _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)));
                  }

                  if (!snapshot.hasData) return const LinearProgressIndicator(color: Color(0xFFE65100));

                  var produtosDocs = snapshot.data!.docs;
                  if (produtosDocs.isEmpty) {
                    return const Text('Nenhum produto cadastrado nessa loja sô! 🌾', style: TextStyle(color: Colors.redAccent));
                  }

                  return DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    hint: const Text('Escolha um item do catálogo'),
                    items: produtosDocs.map((doc) {
                      var dados = doc.data() as Map<String, dynamic>;
                      dados['id'] = doc.id;
                      return DropdownMenuItem<Map<String, dynamic>>(value: dados, child: Text("${dados['nome']} - R\$ ${(dados['preco'] ?? 0.0).toStringAsFixed(2)}"));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _produtoSelecionado = value;
                        _precoUnitario = (value?['preco'] ?? 0.0).toDouble();
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 8),

              // 📊 Contador de Quantidade + Botão de Injetar no carrinho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantidade > 1 ? () => setState(() => _quantidade--) : null,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      ),
                      Text('$_quantidade', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setState(() => _quantidade++),
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100), // Laranja AliUai sô!
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _produtoSelecionado == null ? null : _adicionarItemAoCarrinho,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Item', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              // 🛒 LISTA VISUAL DO CARRINHO SÔ!
              if (_itensCarrinho.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  height: 140, // Limita altura pro teclado não empurrar demais uai!
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _itensCarrinho.length,
                    itemBuilder: (context, index) {
                      var item = _itensCarrinho[index];
                      double totalItem = item['preco_unitario'] * item['quantidade'];
                      return ListTile(
                        dense: true,
                        title: Text("${item['nome_produto']} (x${item['quantidade']})"),
                        subtitle: Text("R\$ ${item['preco_unitario'].toStringAsFixed(2)} un"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("R\$ ${totalItem.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              onPressed: () => setState(() => _itensCarrinho.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 🚦 3. Seletor de Status (Esteira de Produção)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tipo / Status do Pedido:',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _statusPedido,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'entregue', child: Text('🟢 Concluído (Venda de Balcão)')),
                      DropdownMenuItem(value: 'pendente', child: Text('🟡 Recebido por Telefone (Aguardando)')),
                      DropdownMenuItem(value: 'aceito', child: Text('🔥 Para Entrega (Em Preparo)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusPedido = value ?? 'entregue';
                        if (_statusPedido == 'entregue') {
                          _taxaEntregaController.text = "0.00";
                          _taxaEntrega = 0.0;
                          _enderecoController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🛵 4. SEÇÃO DINÂMICA: SÓ APARECE ENDEREÇO SE FOR PARA ENTREGA SÔ!
              if (ehEntrega) ...[
                const Text(
                  'Endereço de Entrega:',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _enderecoController,
                  decoration: InputDecoration(
                    hintText: 'Rua, Número, Bairro e Ponto de Referência',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) => ehEntrega && (value == null || value.trim().isEmpty) ? 'Insira o endereço para o motoboy sô! 🗺️' : null,
                ),
                const SizedBox(height: 16),
              ],

              // 💳 5. Forma de Pagamento & Taxa de Entrega
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Forma de Pagamento:',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _formaPagamento,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: ['Dinheiro', 'Pix Balcão', 'Cartão de Crédito', 'Cartão de Débito', 'Fiado'].map((forma) => DropdownMenuItem(value: forma, child: Text(forma))).toList(),
                          onChanged: (value) => setState(() => _formaPagamento = value ?? 'Dinheiro'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Taxa de Entrega (R\$):',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _taxaEntregaController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          enabled: ehEntrega,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: !ehEntrega ? Colors.grey[200] : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _taxaEntrega = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 📝 6. CAMPO DE OBSERVAÇÃO
              const Text(
                'Observações do Pedido:',
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _observacaoController,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Ex: Tirar cebola, levar troco para R\$ 100, etc...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),

              // 💰 7. Resumo do Valor Total e Botão Final sô!
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Geral:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          'R\$ ${_valorTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 48,
                      width: 180,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E26),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _salvando ? null : _salvarPedidoManual,
                        child: _salvando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Confirmar Venda', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
