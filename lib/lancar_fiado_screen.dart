import 'package:aliuai_painel/models/cliente_fiado_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LancarFiadoScreen extends StatefulWidget {
  final String lojaId;
  const LancarFiadoScreen({super.key, required this.lojaId});

  @override
  State<LancarFiadoScreen> createState() => _LancarFiadoScreenState();
}

class _LancarFiadoScreenState extends State<LancarFiadoScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // 🕹️ Controladores e Focos sô
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final FocusNode _valorFocusNode = FocusNode();
  final FocusNode _descricaoFocusNode = FocusNode();

  ClienteFiadoModel? _clienteSelecionado;
  bool _salvando = false;

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _valorFocusNode.dispose();
    _descricaoFocusNode.dispose();
    super.dispose();
  }

  // 💾 MÉTODO BRUTO PARA SALVAR NO FIREBASE (USA BATCH TRANSACT)
  Future<void> _salvarFiadoNoBanco() async {
    if (!_formKey.currentState!.validate() || _clienteSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um cliente e preencha o valor sô!'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _salvando = true);

    final double valorCompra = double.parse(_valorController.text.replaceAll(',', '.'));
    // Se não digitar nada na descrição, vira "Compra Geral" automática sô!
    final String descricaoCompra = _descricaoController.text.trim().isEmpty ? "Compra Geral no estabelecimento" : _descricaoController.text.trim();

    try {
      final batch = _firestore.batch();

      // 1️⃣ Cria a linha na coleção 'historico_fiado'
      final novaDividaRef = _firestore.collection('historico_fiado').doc();
      batch.set(novaDividaRef, {
        'loja_id': widget.lojaId,
        'cliente_id': _clienteSelecionado!.id,
        'data_compra': FieldValue.serverTimestamp(),
        'descricao': descricaoCompra,
        'valor_original': valorCompra,
        'valor_restante': valorCompra, // 🔥 Nasce igual ao original sô
        'status': 'pendente',
        'pagamentos_parciais': [],
      });

      // 2️⃣ Atualiza a ficha do cliente somando o saldo devedor dele sô!
      final clienteRef = _firestore.collection('clientes_fiado').doc(_clienteSelecionado!.id);
      batch.update(clienteRef, {'saldo_devedor': FieldValue.increment(valorCompra), 'atualizado_em': FieldValue.serverTimestamp()});

      // Executa os dois comandos juntos em uma lapada só!
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiado lançado com sucesso no caderninho! 📒✍️'), backgroundColor: Colors.green));
        // Limpa a tela para o próximo sô
        setState(() {
          _clienteSelecionado = null;
          _valorController.clear();
          _descricaoController.clear();
        });
      }
    } catch (e) {
      print('Erro ao lançar fiado sô: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✍️ Lançar Novo Fiado',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
              ),
              const SizedBox(height: 4),
              Text('Anote uma nova compra na conta corrente de um cliente sô.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Painel do Formulário sô
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Quem está comprando?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),

                          // 📡 BUSCA DINÂMICA DE CLIENTES COM AUTOCOMPLETE SÔ!
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore.collection('clientes_fiado').where('loja_id', isEqualTo: widget.lojaId).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const LinearProgressIndicator(color: Color(0xFFE65100));

                              final listaClientes = snapshot.data!.docs.map((doc) => ClienteFiadoModel.fromFirestore(doc)).toList();

                              return Autocomplete<ClienteFiadoModel>(
                                displayStringForOption: (cliente) => cliente.nome,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return const Iterable<ClienteFiadoModel>.empty();
                                  return listaClientes.where((cliente) => cliente.nome.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (ClienteFiadoModel selecao) {
                                  setState(() {
                                    _clienteSelecionado = selecao;
                                  });
                                  _valorFocusNode.requestFocus(); // Pula pro preço sô!
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(labelText: 'Buscar ou digitar nome do cliente...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          const Text('2. Informações da Venda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              // CAMPO DO VALOR SÔ
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _valorController,
                                  focusNode: _valorFocusNode,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(labelText: 'Valor da Compra (R\$)', prefixText: 'R\$ ', border: OutlineInputBorder()),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório sô!' : null,
                                  onFieldSubmitted: (_) => _descricaoFocusNode.requestFocus(),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // CAMPO DA DESCRIÇÃO (OPCIONAL)
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _descricaoController,
                                  focusNode: _descricaoFocusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'O que ele levou? (Ex: 1kg de arroz, pastel...)',
                                    hintText: 'Deixe em branco para "Compra Geral"',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // BOTÃO DE LANÇAMENTO BRUTO
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE65100),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _salvando
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.menu_book_rounded, color: Colors.white),
                              label: Text(
                                _salvando ? 'Anotando no Caderninho...' : 'Lançar no Fiado',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              onPressed: _salvando ? null : _salvarFiadoNoBanco,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card Lateral de resumo do Cliente selecionado sô
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 1,
                    child: _clienteSelecionado == null
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: const Text('💡 Escolha um cliente ao lado para visualizar a situação atual dele antes de vender sô!', style: TextStyle(color: Colors.grey, height: 1.4)),
                          )
                        : Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ficha do Cliente 👤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Divider(height: 24),
                                Text(_clienteSelecionado!.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 4),
                                Text('📞 ${_clienteSelecionado!.telefone}', style: const TextStyle(color: Colors.grey)),
                                const Divider(height: 32),
                                const Text('Dívida Acumulada Anterior:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  'R\$ ${_clienteSelecionado!.saldoDevedor.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _clienteSelecionado!.saldoDevedor > 0 ? Colors.redAccent : Colors.green),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
