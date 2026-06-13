import 'package:aliuai_painel/lancar_fiado_screen.dart';
import 'package:aliuai_painel/models/cliente_fiado_model.dart';
import 'package:aliuai_painel/models/divida_fiado_model.dart';
import 'package:aliuai_painel/util/formatar_telefone.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  // 🔍 Controles do Filtro e Paginação Dinâmica sô
  final TextEditingController _buscaController = TextEditingController();
  String _textoBusca = "";
  int _limiteAtual = 10; // 🔥 Nasce trazendo apenas 10 clientes sô!
  bool _temMaisClientes = true;

  @override
  void dispose() {
    _buscaController.dispose();
    _abatimentoController.dispose();
    super.dispose();
  }

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
                  autofocus: true,
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

                          final clienteRef = _firestore.collection('clientes_fiado').doc(cliente.id);
                          batch.update(clienteRef, {'saldo_devedor': FieldValue.increment(valorCompra), 'atualizado_em': FieldValue.serverTimestamp()});

                          await batch.commit();

                          final snapAtualizado = await clienteRef.get();
                          if (snapAtualizado.exists && mounted) {
                            setState(() {
                              _clienteSelecionado = ClienteFiadoModel.fromFirestore(snapAtualizado);
                            });
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
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
  // 🟢 TELA 1: LISTA GERAL DE CLIENTES DO FIADO COM FILTRO E PAGINAÇÃO SÔ!
  // =========================================================================
  Widget _construirListaClientes(bool ehCelular) {
    return Padding(
      key: const ValueKey('lista_clientes'),
      padding: EdgeInsets.all(ehCelular ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚨 TOPO RESPONSIVO
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

          const SizedBox(height: 24),

          // 🔍 CAIXA DE PESQUISA HÍBRIDA
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: TextField(
              controller: _buscaController,
              onChanged: (valor) {
                setState(() {
                  _textoBusca = valor.trim().toLowerCase();
                  _limiteAtual = 10; // Resetamos a paginação ao digitar sô!
                });
              },
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome ou telefone do cliente sô...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE65100)),
                suffixIcon: _textoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {
                            _textoBusca = "";
                            _limiteAtual = 10;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 📡 LISTA COM STREAMBUILDER E PAGINAÇÃO CONTROLADA SÔ!
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Passamos o _limiteAtual direto na Query do Stream sô!
              stream: _firestore.collection('clientes_fiado').where('loja_id', isEqualTo: widget.lojaId).orderBy('nome').limit(_limiteAtual).snapshots(),
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
                        const Text('Nenhum cliente registrado sô. 🎉', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  );
                }

                final devedoresCompletos = snapshot.data!.docs;

                // Filtramos em memória por Nome ou Telefone sô
                final devedoresFiltrados = devedoresCompletos.where((doc) {
                  final cliente = ClienteFiadoModel.fromFirestore(doc);
                  if (_textoBusca.isEmpty) return true;
                  String telefoneLimpo = cliente.telefone.replaceAll(RegExp(r'[^0-9]'), '');
                  return cliente.nome.toLowerCase().contains(_textoBusca) || telefoneLimpo.contains(_textoBusca);
                }).toList();

                // Se trouxe menos registros do que o limite, a fonte secou sô!
                _temMaisClientes = devedoresCompletos.length == _limiteAtual;

                if (devedoresFiltrados.isEmpty) {
                  return Center(
                    child: Text('Nenhum cliente encontrado para "$_textoBusca" 🔍', style: const TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: devedoresFiltrados.length + (_temMaisClientes ? 1 : 0), // +1 para a linha do botão sô!
                  itemBuilder: (context, index) {
                    // ⏭️ LINHA DO BOTÃO CARREGAR MAIS SÔ!
                    if (index == devedoresFiltrados.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: const BorderSide(color: Color(0xFFCCCCCC)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            label: const Text('Carregar próximos 10 clientes sô', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                _limiteAtual += 10; // 🔥 Puxa mais 10 em tempo real!
                              });
                            },
                          ),
                        ),
                      );
                    }

                    final cliente = ClienteFiadoModel.fromFirestore(devedoresFiltrados[index]);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      child: ListTile(
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          cliente.telefone.isEmpty ? "Sem telefone" : FormatarTelefone.formatarTelefone(cliente.telefone), // 🔥 Adicionado a função aqui!
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
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
                            _clienteSelecionado = cliente;
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
    if (_clienteSelecionado == null) return const SizedBox.shrink(); // Vacina aplicada sô!
    final cliente = _clienteSelecionado!;

    return Padding(
      key: const ValueKey('extrato_cliente'),
      padding: EdgeInsets.all(ehCelular ? 16.0 : 32.0),
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

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: ehCelular
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                Text(
                                  cliente.telefone.isEmpty ? 'Sem telefone' : '📞 ${FormatarTelefone.formatarTelefone(cliente.telefone)}', // 🔥 Adicionado aqui!
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentGeometry.bottomRight,
                        child: TextButton.icon(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.green), // 🔥 ÍCONE CORRIGIDO SÔ!
                          label: Text(
                            'Enviar Saldo Geral',
                            style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: false),
                        ),
                      ),
                    ],
                  )
                : Row(
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

                              Text(
                                cliente.telefone.isEmpty ? 'Sem telefone' : 'WhatsApp: ${FormatarTelefone.formatarTelefone(cliente.telefone)}', // 🔥 Adicionado aqui!
                                style: const TextStyle(color: Colors.grey),
                              ),
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
                          TextButton.icon(
                            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 22, color: Colors.green), // 🔥 ÍCONE CORRIGIDO SÔ!
                            label: Text(
                              'Enviar Saldo Geral',
                              style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: false),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          const Text('Notas Pendentes e Compras:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

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

          if (_dividasSelecionadasIds.isNotEmpty) _construirBarraAbatimento(ehCelular),
        ],
      ),
    );
  }

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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: FaIcon(FontAwesomeIcons.whatsapp, size: 16), // 🔥 ÍCONE CORRIGIDO SÔ!
                        label: const Text('Cobrar Zap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _processandoAbatimento ? null : () => _confirmarEProcessarAbatimento(),
                        child: _processandoAbatimento
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Abater',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text('${_dividasSelecionadasIds.length} notas selecionadas para abater sô!', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  ),
                  icon: const Icon(Icons.send_rounded), // 🔥 ÍCONE CORRIGIDO SÔ!
                  label: const Text('Enviar cobrança no Zap', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _enviarCobrancaWhatsApp(apenasSelecionadas: true),
                ),
                const SizedBox(width: 16),
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
    );
  }

  void _abrirModalNovoCliente() {
    final nomeCtrl = TextEditingController();
    final foneCtrl = TextEditingController();
    final enderecoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cadastrar Novo Cliente 👤', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nome completo', counterText: ''),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: foneCtrl,
              keyboardType: TextInputType.phone,
              // 🔥 ADICIONADO: Limita a digitação para o tamanho do celular com máscara sô!
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'Telefone/WhatsApp',
                hintText: '(31) 98888-7777', // Hint mais amigável sô!
                counterText: '', // Esconde o contador de caracteres para o layout ficar limpo
              ),
              // 🛠️ A MÁGICA DA FORMATAÇÃO EM TEMPO REAL SÔ:
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  // 1. Remove tudo o que não for número sô
                  String texto = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

                  // Se o lojista estiver apagando, deixa o homem trabalhar em paz sô
                  if (newValue.text.length < oldValue.text.length) {
                    return newValue;
                  }

                  String textoFormatado = "";

                  // 2. Monta a máscara certinha sem espaços duplicados sô!
                  if (texto.length > 0) {
                    textoFormatado += "(${texto.substring(0, texto.length.clamp(0, 2))}";
                  }
                  if (texto.length > 2) {
                    // Juntamos o fecha parêntese com o espaço padrão sô: ") "
                    textoFormatado += ") ${texto.substring(2, texto.length.clamp(2, 7))}";
                  }
                  if (texto.length > 7) {
                    // Corta os primeiros 5 dígitos do número e mete o hífen pro restante sô
                    textoFormatado = "(${texto.substring(0, 2)}) ${texto.substring(2, 7)}-${texto.substring(7, texto.length.clamp(7, 11))}";
                  }

                  return TextEditingValue(
                    text: textoFormatado,
                    selection: TextSelection.collapsed(offset: textoFormatado.length),
                  );
                }),
              ],
            ),
            TextField(
              controller: enderecoCtrl,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Endereço', counterText: ''),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () async {
              if (nomeCtrl.text.trim().isEmpty) return;

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

      for (String dividaId in _dividasSelecionadasIds) {
        if (dinheiroRestante <= 0) break;

        final docRef = _firestore.collection('historico_fiado').doc(dividaId);
        final docSnap = await docRef.get();

        if (docSnap.exists) {
          final dados = docSnap.data() as Map<String, dynamic>;
          double valorRestanteNota = (dados['valor_restante'] ?? 0.0).toDouble();

          if (dinheiroRestante >= valorRestanteNota) {
            dinheiroRestante -= valorRestanteNota;
            totalAbatidoNoSaldoDoCliente += valorRestanteNota;

            final novoPagamento = {'data_pagamento': Timestamp.now(), 'valor_pago': valorRestanteNota};

            batch.update(docRef, {
              'valor_restante': 0.0,
              'status': 'pago',
              'pagamentos_parciais': FieldValue.arrayUnion([novoPagamento]),
            });
          } else {
            double valorAbatidoParcial = dinheiroRestante;
            double novoValorRestanteNota = valorRestanteNota - valorAbatidoParcial;
            totalAbatidoNoSaldoDoCliente += valorAbatidoParcial;
            dinheiroRestante = 0.0;

            final novoPagamento = {'data_pagamento': Timestamp.now(), 'valor_pago': valorAbatidoParcial};

            batch.update(docRef, {
              'valor_restante': novoValorRestanteNota,
              'status': 'parcial',
              'pagamentos_parciais': FieldValue.arrayUnion([novoPagamento]),
            });
          }
        }
      }

      final clienteRef = _firestore.collection('clientes_fiado').doc(_clienteSelecionado!.id);
      batch.update(clienteRef, {'saldo_devedor': FieldValue.increment(-totalAbatidoNoSaldoDoCliente), 'atualizado_em': FieldValue.serverTimestamp()});

      await batch.commit();

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

    String telefoneLimpo = cliente.telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!telefoneLimpo.startsWith('55')) {
      telefoneLimpo = '55$telefoneLimpo';
    }

    String messaging = '';

    if (apenasSelecionadas) {
      if (_dividasSelecionadasIds.isEmpty) return;

      messaging = 'Olá, *${cliente.nome}*! Passando para te enviar o detalhe das seguintes notas em aberto aqui no nosso estabelecimento:\n\n';
      double totalSelecionado = 0.0;

      for (String id in _dividasSelecionadasIds) {
        final doc = await _firestore.collection('historico_fiado').doc(id).get();
        if (doc.exists) {
          final dados = doc.data() as Map<String, dynamic>;
          String desc = dados['descricao'] ?? 'Compra';
          double valor = (dados['valor_restante'] ?? 0.0).toDouble();
          totalSelecionado += valor;

          messaging += '📌 *$desc* - R\$ ${valor.toStringAsFixed(2)}\n';
        }
      }

      messaging += '\n💰 *Subtotal das notas selecionadas: R\$ ${totalSelecionado.toStringAsFixed(2)}*';
      messaging += '\n\nQuando puder dar uma passadinha para acertar essas notas, eu agradeço demais sô! 👍';
    } else {
      messaging = 'Olá, *${cliente.nome}*!\n\nPassando para te lembrar do seu saldo atual na nossa *Caderneta de Fiado*.\n\n';
      messaging += '💵 O valor total acumulado é de: *R\$ ${cliente.saldoDevedor.toStringAsFixed(2)}*.\n\n';
      messaging += 'Se quiser o extrato detalhado de todas as compras, é só me avisar por aqui sô! Obrigado pela preferência! 🙏✨';
    }

    final Uri urlUri = Uri.parse('https://wa.me/$telefoneLimpo?text=${Uri.encodeFull(messaging)}');

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
