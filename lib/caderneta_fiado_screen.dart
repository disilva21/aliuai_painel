import 'package:aliuai_painel/lancar_fiado_screen.dart';
import 'package:aliuai_painel/models/cliente_fiado_model.dart';
import 'package:aliuai_painel/models/divida_fiado_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class CadernetaFiadoScreen extends StatefulWidget {
  final String lojaId;
  const CadernetaFiadoScreen({super.key, required this.lojaId});

  @override
  State<CadernetaFiadoScreen> createState() => _CadernetaFiadoScreenState();
}

class _CadernetaFiadoScreenState extends State<CadernetaFiadoScreen> {
  final _firestore = FirebaseFirestore.instance;

  // 🕹️ Controles de Estado
  ClienteFiadoModel? _clienteSelecionado; // Se for nulo, mostra a lista de clientes sô!
  final List<String> _dividasSelecionadasIds = []; // Controla os checkboxes de abatimento
  final TextEditingController _abatimentoController = TextEditingController();
  bool _processandoAbatimento = false;

  @override
  Widget build(BuildContext context) {
    // 🖥️ Responsividade para o painel Web sô
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _clienteSelecionado == null
            ? _construirListaClientes(ehCelular) // 🟢 Tela 1: Lista Geral
            : _construirExtratoCliente(ehCelular), // 🟠 Tela 2: O Caderninho do Cliente
      ),
    );
  }

  // 🔥 NOVA FUNÇÃO: Abre a janelinha de lançamento direto para o cliente selecionado!
  void _abrirModalLancarFiado(ClienteFiadoModel cliente) {
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool salvandoModal = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // StatefulBuilder para controlar o botão de carregar sô
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Anotar na conta de: ${cliente.nome} 📒✍️', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: valorCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true, // Já abre piscando no preço sô!
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Valor da Compra (R\$)', prefixText: 'R\$ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'O que ele levou? (Opcional)', hintText: 'Ex: 1kg de arroz, pastel...', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: salvandoModal ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                onPressed: salvandoModal
                    ? null
                    : () async {
                        final double? valorCompra = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
                        if (valorCompra == null || valorCompra <= 0) return;

                        setModalState(() => salvandoModal = true);

                        try {
                          final batch = _firestore.batch();
                          final String descricaoCompra = descCtrl.text.trim().isEmpty ? "Compra Geral" : descCtrl.text.trim();

                          // 1️⃣ Lança no histórico
                          final novaDividaRef = _firestore.collection('historico_fiado').doc();
                          batch.set(novaDividaRef, {
                            'loja_id': widget.lojaId,
                            'cliente_id': cliente.id,
                            'data_compra': FieldValue.serverTimestamp(),
                            'descricao': descricaoCompra,
                            'valor_original': valorCompra,
                            'valor_restante': valorCompra,
                            'status': 'pendente',
                            'pagamentos_parciais': [],
                          });

                          // 2️⃣ Incrementa o saldo do cliente sô!
                          final clienteRef = _firestore.collection('clientes_fiado').doc(cliente.id);
                          batch.update(clienteRef, {'saldo_devedor': FieldValue.increment(valorCompra), 'atualizado_em': FieldValue.serverTimestamp()});

                          await batch.commit();

                          if (context.mounted) {
                            Navigator.pop(context); // Fecha o modal sô
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiado anotado no caderno! 📝'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          setModalState(() => salvandoModal = false);
                        }
                      },
                child: salvandoModal
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Venda', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 🟢 TELA 1: LISTA GERAL DE CLIENTES DO FIADO CORRIGIDA E RESPONSIVA SÔ!
  // =========================================================================
  Widget _construirListaClientes(bool ehCelular) {
    return Padding(
      key: const ValueKey('lista_clientes'),
      padding: EdgeInsets.all(ehCelular ? 16.0 : 32.0), // Margem menor no celular sô
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚨 TOPO RESPONSIVO: Se for celular, empilha o título e o botão!
          ehCelular
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📒 Caderneta de Fiado',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                    ),
                    const SizedBox(height: 4),
                    Text('Contas de balcão dos seus clientes.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 16),
                    // Botão ocupa a largura toda no celular sô!
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          'Cadastrar Cliente',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _abrirModalNovoCliente(),
                      ),
                    ),
                  ],
                )
              : Row(
                  // 🖥️ Layout Web Normal (Lado a Lado sô)
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📒 Caderneta de Fiado (Contas a Receber)',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                        ),
                        const SizedBox(height: 4),
                        Text('Gerencie as contas correntes de balcão dos seus clientes da feira.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                      label: const Text(
                        'Cadastrar Cliente',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _abrirModalNovoCliente(),
                    ),
                  ],
                ),

          SizedBox(height: ehCelular ? 24 : 32),

          // 📡 Lista de Devedores
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('clientes_fiado').where('loja_id', isEqualTo: widget.lojaId).orderBy('nome').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erro ao carregar devedores sô: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_rounded, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Nenhum cliente com fiado registrado sô. 🎉', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  );
                }

                final devedores = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: devedores.length,
                  itemBuilder: (context, index) {
                    final cliente = ClienteFiadoModel.fromFirestore(devedores[index]);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200] ?? Colors.grey),
                      ),
                      child: ListTile(
                        // Ajusta os espaçamentos internos se for celular sô!
                        contentPadding: EdgeInsets.symmetric(horizontal: ehCelular ? 16 : 24, vertical: ehCelular ? 4 : 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE65100).withOpacity(0.1),
                          child: Text(
                            cliente.nome[0].toUpperCase(),
                            style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          cliente.nome,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: ehCelular ? 15 : 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis, // Corta o nome com '...' se for gigante sô
                        ),
                        subtitle: Text(cliente.telefone.isEmpty ? "Sem telefone" : cliente.telefone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Saldo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  'R\$ ${cliente.saldoDevedor.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: ehCelular ? 16 : 18, fontWeight: FontWeight.bold, color: cliente.saldoDevedor > 0 ? Colors.redAccent : Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _clienteSelecionado = cliente; // Abre o extrato sô!
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🟠 TELA 2: EXTRATO DETALHADO CORRIGIDO E RESPONSIVO SÔ!
  Widget _construirExtratoCliente(bool ehCelular) {
    final cliente = _clienteSelecionado!;

    return Padding(
      key: const ValueKey('extrato_cliente'),
      padding: EdgeInsets.all(ehCelular ? 16.0 : 32.0), // Margem menor no celular sô
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botão Voltar
          TextButton.icon(
            onPressed: () => setState(() => _clienteSelecionado = null),
            icon: const Icon(Icons.arrow_back, color: Color(0xFFE65100)),
            label: const Text(
              'Voltar para a lista',
              style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // 🚨 CABEÇALHO RESPONSIVO: Se for celular, vira Column sô!
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFEEEEEE)),
            ),
            child: ehCelular
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Dados do Cliente
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE65100),
                            child: Text(
                              cliente.nome[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cliente.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('📞 ${cliente.telefone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.whatshot_outlined, color: Colors.green, size: 20),
                            label: Text('Enviar Saldo Geral'),
                            onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: false), // 🔥 Saldo Geral!
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // 2. Mostrador do Saldo Devedor
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dívida Total:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(
                            'R\$ ${cliente.saldoDevedor.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Botão Lançar Fiado ocupando a largura toda no celular sô!
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                          label: const Text(
                            'Lançar Novo Fiado',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _abrirModalLancarFiado(cliente),
                        ),
                      ),
                    ],
                  )
                : Row(
                    // 🖥️ Layout Web Normal (Lado a Lado sô)
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFE65100),
                            child: Text(
                              cliente.nome[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cliente.nome, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('WhatsApp: ${cliente.telefone}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                        label: const Text(
                          'Lançar Novo Fiado',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _abrirModalLancarFiado(cliente),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total da Dívida Atual', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            'R\$ ${cliente.saldoDevedor.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          const Text('Notas Pendentes e Compras:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // 📡 Lista de contas pendentes/parciais sô!
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('historico_fiado')
                  .where('cliente_id', isEqualTo: cliente.id)
                  .where('status', whereIn: ['pendente', 'parcial'])
                  .orderBy('data_compra', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma conta pendente sô! 👍', style: TextStyle(color: Colors.grey)),
                  );
                }

                final dividasDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: dividasDocs.length,
                  itemBuilder: (context, index) {
                    final divida = DividaFiadoModel.fromFirestore(dividasDocs[index]);
                    final bool selecionada = _dividasSelecionadasIds.contains(divida.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: selecionada ? const Color(0xFFE65100).withOpacity(0.02) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: selecionada ? const Color(0xFFE65100) : const Color(0xFFEEEEEE)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Checkbox(
                              activeColor: const Color(0xFFE65100),
                              value: selecionada,
                              onChanged: (valor) {
                                setState(() {
                                  if (valor == true) {
                                    _dividasSelecionadasIds.add(divida.id!);
                                  } else {
                                    _dividasSelecionadasIds.remove(divida.id!);
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    divida.descricao,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: ehCelular ? 14 : 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${divida.dataCompra.day}/${divida.dataCompra.month}/${divida.dataCompra.year}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (divida.status == 'parcial')
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                  'PARCIAL',
                                  style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'R\$ ${divida.valorRestante.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: ehCelular ? 15 : 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                if (divida.valorOriginal > divida.valorRestante)
                                  Text(
                                    'de R\$ ${divida.valorOriginal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 💰 BARRA INFERIOR DE ABATIMENTO DA CONTA SÔ!
          if (_dividasSelecionadasIds.isNotEmpty) _construirBarraAbatimento(ehCelular),
        ],
      ),
    );
  }

  // 🔥 AJUSTADO: Passando a responsividade para a barra inferior de pagamento também!
  Widget _construirBarraAbatimento(bool ehCelular) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ehCelular
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_dividasSelecionadasIds.length} notas selecionadas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                TextField(
                  controller: _abatimentoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor Pago', prefixText: 'R\$ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _processandoAbatimento ? null : () => _confirmarEProcessarAbatimento(),
                    child: _processandoAbatimento
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Confirmar Abatimento',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // Layout Web
                  children: [
                    Expanded(
                      child: Text('${_dividasSelecionadasIds.length} notas selecionadas para abater sô!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _abatimentoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Valor Pago pelo Cliente', prefixText: 'R\$ ', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
                      onPressed: _processandoAbatimento ? null : () => _confirmarEProcessarAbatimento(),
                      child: _processandoAbatimento
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirmar Abatimento',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
                // 💰 Dentro do _construirBarraAbatimento (Tanto Web quanto Mobile), coloque do lado do botão de Abater:
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.whatshot_outlined),
                  label: const Text('Enviar cobrança no Zap', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: true), // 🔥 Apenas as selecionadas sô!
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // 💾 BACKEND LOCAL: MÉTODOS DE CADASTRO E ABATIMENTO SÔ
  // =========================================================================
  void _abrirModalNovoCliente() {
    final nomeCtrl = TextEditingController();
    final foneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar Novo Cliente no Fiado 👤'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome Completo do Cliente sô'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: foneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone/WhatsApp', hintText: '31988887777'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () async {
              if (nomeCtrl.text.trim().isEmpty) return;

              // Cria o cliente no banco sô!
              await _firestore.collection('clientes_fiado').add({
                'loja_id': widget.lojaId,
                'nome': nomeCtrl.text.trim(),
                'telefone': foneCtrl.text.trim(),
                'saldo_devedor': 0.0,
                'atualizado_em': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salvar Cliente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEProcessarAbatimento() async {
    // 1. Valida o valor digitado sô
    final double? valorPagoOriginal = double.tryParse(_abatimentoController.text.replaceAll(',', '.'));
    if (valorPagoOriginal == null || valorPagoOriginal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um valor válido para o pagamento sô! 💰'), backgroundColor: Colors.orange));
      return;
    }

    if (_dividasSelecionadasIds.isEmpty) return;

    setState(() => _processandoAbatimento = true);

    try {
      final batch = _firestore.batch();
      double dinheiroRestante = valorPagoOriginal;
      double totalAbatidoNoSaldoDoCliente = 0.0;

      // 2. Busca os documentos reais das dívidas selecionadas para saber quanto cada uma deve sô!
      for (String dividaId in _dividasSelecionadasIds) {
        if (dinheiroRestante <= 0) break; // Se o dinheiro que o cliente trouxe acabou, para o laço!

        final docRef = _firestore.collection('historico_fiado').doc(dividaId);
        final docSnap = await docRef.get();

        if (docSnap.exists) {
          final dados = docSnap.data() as Map<String, dynamic>;
          double valorRestanteNota = (dados['valor_restante'] ?? 0.0).toDouble();

          // 🧠 A MÁGICA DO ABATIMENTO ITEM POR ITEM SÔ:
          if (dinheiroRestante >= valorRestanteNota) {
            // CASO A: O dinheiro dá para pagar essa nota INTEIRA!
            dinheiroRestante -= valorRestanteNota;
            totalAbatidoNoSaldoDoCliente += valorRestanteNota;

            // Cria o registro do picadinho/histórico interno da nota
            final novoPagamento = {'data_pagamento': Timestamp.now(), 'valor_pago': valorRestanteNota};

            batch.update(docRef, {
              'valor_restante': 0.0,
              'status': 'pago',
              'pagamentos_parciais': FieldValue.arrayUnion([novoPagamento]),
            });
          } else {
            // CASO B: O dinheiro só dá para pagar um PEDAÇO dessa nota (Abatimento Parcial!)
            double valorAbatidoParcial = dinheiroRestante;
            double novoValorRestanteNota = valorRestanteNota - valorAbatidoParcial;
            totalAbatidoNoSaldoDoCliente += valorAbatidoParcial;
            dinheiroRestante = 0.0; // Dinheiro do cliente zerou sô!

            final novoPagamento = {'data_pagamento': Timestamp.now(), 'valor_pago': valorAbatidoParcial};

            batch.update(docRef, {
              'valor_restante': novoValorRestanteNota,
              'status': 'parcial',
              'pagamentos_parciais': FieldValue.arrayUnion([novoPagamento]),
            });
          }
        }
      }

      // 3. Atualiza a ficha principal do cliente subtraindo tudo o que foi abatido sô!
      final clienteRef = _firestore.collection('clientes_fiado').doc(_clienteSelecionado!.id);
      batch.update(clienteRef, {
        // Usamos o decremento negativo para abater o saldo real sô!
        'saldo_devedor': FieldValue.increment(-totalAbatidoNoSaldoDoCliente),
        'atualizado_em': FieldValue.serverTimestamp(),
      });

      // 4. Envia todos os comandos pro Firebase de uma vez só!
      await batch.commit();

      // 5. Recarrega os dados do cliente localmente para atualizar o cabeçalho na tela sô!
      final clienteAtualizadoSnap = await clienteRef.get();

      if (mounted) {
        setState(() {
          if (clienteAtualizadoSnap.exists) {
            _clienteSelecionado = ClienteFiadoModel.fromFirestore(clienteAtualizadoSnap);
          }
          _dividasSelecionadasIds.clear();
          _abatimentoController.clear();
          _processandoAbatimento = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abatimento de R\$ ${totalAbatidoNoSaldoDoCliente.toStringAsFixed(2)} processado! 💰🎉'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('Erro bruto no abatimento sô: $e');
      if (mounted) {
        setState(() => _processandoAbatimento = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao processar abatimento. Tente novamente sô!'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _enviarCobrancaWhatsApp({required bool apenasSelecionadas}) async {
    final cliente = _clienteSelecionado!;
    if (cliente.telefone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esse cliente não tem telefone cadastrado sô! 📞'), backgroundColor: Colors.orange));
      return;
    }

    // 1. Limpa o número do telefone (deixa só números e enfia o DDI 55 do Brasil sô)
    String telefoneLimpo = cliente.telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!telefoneLimpo.startsWith('55')) {
      telefoneLimpo = '55$telefoneLimpo';
    }

    String mensagem = '';

    if (apenasSelecionadas) {
      // =========================================================================
      // MODO A: COBRANÇA DE ITENS SELECIONADOS SÔ!
      // =========================================================================
      if (_dividasSelecionadasIds.isEmpty) return;

      mensagem = 'Olá, *${cliente.nome}*! Passando para te enviar o detalhe das seguintes notas em aberto aqui no nosso estabelecimento:\n\n';
      double totalSelecionado = 0.0;

      // Buscamos os documentos direto na coleção do histórico (ou você pode puxar da tela sô!)
      for (String id in _dividasSelecionadasIds) {
        final doc = await _firestore.collection('historico_fiado').doc(id).get();
        if (doc.exists) {
          final dados = doc.data() as Map<String, dynamic>;
          String desc = dados['descricao'] ?? 'Compra';
          double valor = (dados['valor_restante'] ?? 0.0).toDouble();
          totalSelecionado += valor;

          mensagem += '📌 *$desc* - R\$ ${valor.toStringAsFixed(2)}\n';
        }
      }

      mensagem += '\n💰 *Subtotal das notas selecionadas: R\$ ${totalSelecionado.toStringAsFixed(2)}*';
      mensagem += '\n\nQuando puder dar uma passadinha para acertar essas notas, eu agradeço demais sô! 👍';
    } else {
      // =========================================================================
      // MODO B: SALDO GERAL DO CADERNINHO sô!
      // =========================================================================
      mensagem = 'Olá, *${cliente.nome}*!\n\nPassando para te lembrar do seu saldo atual na nossa *Caderneta de Fiado*.\n\n';
      mensagem += '💵 O valor total acumulado é de: *R\$ ${cliente.saldoDevedor.toStringAsFixed(2)}*.\n\n';
      mensagem += 'Se quiser o extrato detalhado de todas as compras, é só me avisar por aqui sô! Obrigado pela preferência! 🙏✨';
    }

    // 2. Converte o texto para o formato que a URL do navegador entende sô (Uri.encodeFull)
    final Uri urlUri = Uri.parse('https://wa.me/$telefoneLimpo?text=${Uri.encodeFull(mensagem)}');

    // 3. Dispara o WhatsApp Web ou o App do Celular sô!
    try {
      if (await launchUrl(urlUri, mode: LaunchMode.externalApplication)) {
        print('WhatsApp aberto com sucesso sô!');
      } else {
        throw 'Não foi possível abrir o WhatsApp';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao abrir o WhatsApp sô. Verifique se o app está instalado.'), backgroundColor: Colors.red));
    }
  }
}
