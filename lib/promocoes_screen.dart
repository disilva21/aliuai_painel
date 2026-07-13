import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromocoesScreen extends StatefulWidget {
  final String lojaId;

  const PromocoesScreen({super.key, required this.lojaId});

  @override
  State<PromocoesScreen> createState() => _PromocoesScreenState();
}

class _PromocoesScreenState extends State<PromocoesScreen> {
  final _firestore = FirebaseFirestore.instance;
  int _limitePromocoes = 0;
  int _promocoesAtivasAgora = 0;

  @override
  void initState() {
    super.initState();
    _buscarLimiteDaLoja();
  }

  Future<void> _buscarLimiteDaLoja() async {
    final doc = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();
    if (doc.exists && mounted) {
      setState(() {
        _limitePromocoes = doc.data()?['limite_promocoes'] ?? 0;
      });
    }
  }

  /// 🔥 MODAL DE CONTRATAÇÃO DE NOVO PLANO (UPSELL)
  void _mostrarAvisoLimite() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.amber[800], size: 28),
              const SizedBox(width: 12),
              const Text('Limite Atingido! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sua loja já atingiu o limite máximo de *$_limitePromocoes* ofertas ativas permitidas no seu plano atual.', style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Assine o Plano Master por apenas R\$ 59,90/mês e libere até 50 promoções simultâneas!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Clique na aba "Planos de Assinatura" no menu lateral para escolher seu novo plano! 😉'), backgroundColor: Colors.blue));
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  /// Ativa a promoção no produto usando o novo campo padrão
  Future<void> _ativarPromocao(String produtoId, double valorPromocional) async {
    try {
      await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').doc(produtoId).update({'promocao': true, 'preco_promocional': valorPromocional});
    } catch (e) {
      print('Erro ao ativar promoção: $e');
    }
  }

  /// Desativa a promoção (O campo 'preco' continua intacto no banco)
  Future<void> _removerPromocao(String produtoId) async {
    await _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').doc(produtoId).update({'promocao': false, 'preco_promocional': 0.0});
  }

  /// Modal que abre direto da linha do produto (já sabe qual é o produto)
  void _abrirModalPromocao(String produtoId, String nome, double precoBase) {
    if (_promocoesAtivasAgora >= _limitePromocoes) {
      _mostrarAvisoLimite();
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Promocionar: $nome', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preço Actual: R\$ ${precoBase.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço Promocional (R\$)', prefixText: 'R\$ ', border: OutlineInputBorder()),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            onPressed: () {
              final novoPreco = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
              if (novoPreco > 0 && novoPreco < precoBase) {
                _ativarPromocao(produtoId, novoPreco);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O preço promocional deve ser menor que o original, sô!'), backgroundColor: Colors.amber));
              }
            },
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalNovaPromocao() {
    if (_promocoesAtivasAgora >= _limitePromocoes) {
      _mostrarAvisoLimite();
      return;
    }

    String? produtoSelecionadoId;
    double precoBaseDoProduto = 0.0;
    String nomeProdutoSelecionado = '';
    final precoPromoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Nova Promoção'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione o produto:'),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').where('promocao', isEqualTo: false).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();

                      final produtosDisponiveis = snapshot.data!.docs;

                      if (produtosDisponiveis.isEmpty) {
                        return const Text('Nenhum produto disponível para promoção.', style: TextStyle(color: Colors.red));
                      }

                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: produtoSelecionadoId,
                        items: produtosDisponiveis.map((doc) {
                          final dados = doc.data() as Map<String, dynamic>;
                          String nomeProd = dados['nome'] ?? '';
                          double precoProd = (dados['preco'] ?? 0.0).toDouble();

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text('$nomeProd (R\$ ${precoProd.toStringAsFixed(2)})'),
                            onTap: () {
                              precoBaseDoProduto = precoProd;
                              nomeProdutoSelecionado = nomeProd;
                            },
                          );
                        }).toList(),
                        onChanged: (novoId) {
                          setModalState(() {
                            produtoSelecionadoId = novoId;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: precoPromoController,
                    enabled: produtoSelecionadoId != null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Preço Promocional (R\$)', prefixText: 'R\$ ', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: produtoSelecionadoId == null
                      ? null
                      : () {
                          final novoPreco = double.tryParse(precoPromoController.text.replaceAll(',', '.')) ?? 0.0;
                          if (novoPreco > 0 && novoPreco < precoBaseDoProduto) {
                            _ativarPromocao(produtoSelecionadoId!, novoPreco);
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Ativar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Captura a largura para aplicar a responsividade cirúrgica sô!
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelularGeral = larguraTela < 800;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏷️ Gestão de Ofertas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text(
                  'Limites: $_promocoesAtivasAgora / $_limitePromocoes',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _promocoesAtivasAgora >= _limitePromocoes ? Colors.red : Colors.orange),
                ),
                const SizedBox(height: 4),
                const Text('Ative ou pause suas promoções em tempo real.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('estabelecimentos').doc(widget.lojaId).collection('produtos').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final produtos = snapshot.data!.docs;
                  _promocoesAtivasAgora = produtos.where((doc) => (doc.data() as Map)['promocao'] == true).length;

                  if (produtos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum produto cadastrado ainda, uai!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: produtos.length,
                    itemBuilder: (context, index) {
                      final dados = produtos[index].data() as Map<String, dynamic>;
                      final id = produtos[index].id;

                      final String nome = dados['nome'] ?? '';
                      final double precoBase = (dados['preco'] ?? 0.0).toDouble();
                      final double precoPromo = (dados['preco_promocional'] ?? 0.0).toDouble();
                      final bool emPromocao = dados['promocao'] ?? false;

                      // 🔥 COMPONENTIZAÇÃO DO BOTÃO DE AÇÃO PARA EVITAR REPETIÇÃO SÔ!
                      final Widget botaoAcao = emPromocao
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                                elevation: 0,
                                minimumSize: ehCelularGeral ? const Size(double.infinity, 48) : null,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.label_off, size: 16),
                              label: const Text('Encerrar Promo', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _removerPromocao(id),
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _promocoesAtivasAgora >= _limitePromocoes ? Colors.grey[100] : Colors.amber[50],
                                foregroundColor: _promocoesAtivasAgora >= _limitePromocoes ? Colors.grey : Colors.amber[900],
                                elevation: 0,
                                minimumSize: ehCelularGeral ? const Size(double.infinity, 48) : null,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.local_offer, size: 16),
                              label: const Text('Colocar em Promoção', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _abrirModalPromocao(id, nome, precoBase),
                            );

                      // 🚨 REVOLUÇÃO RESPONSIVA DO CARD SÔ:
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFEEEEEE)),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ehCelularGeral
                              ? Column(
                                  // 📱 SE FOR CELULAR: Empilha os dados sem estourar a tela sô!
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    emPromocao
                                        ? Row(
                                            children: [
                                              Text(
                                                'De R\$ ${precoBase.toStringAsFixed(2)}',
                                                style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'por R\$ ${precoPromo.toStringAsFixed(2)}',
                                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          )
                                        : Text('R\$ ${precoBase.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(color: Color(0xFFF5F5F5)),
                                    ),
                                    botaoAcao, // Botão esticado ocupando toda a base no mobile!
                                  ],
                                )
                              : Row(
                                  // 🖥️ SE FOR WEB/DESKTOP: Tudo na mesma linha bem espaçado sô!
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          emPromocao
                                              ? Row(
                                                  children: [
                                                    Text(
                                                      'De R\$ ${precoBase.toStringAsFixed(2)} ',
                                                      style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13),
                                                    ),
                                                    Text(
                                                      ' por  R\$ ${precoPromo.toStringAsFixed(2)}',
                                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                )
                                              : Text('R\$ ${precoBase.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[700])),
                                        ],
                                      ),
                                    ),
                                    botaoAcao, // Botão compacto fixado no canto direito!
                                  ],
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FloatingActionButton.extended(
        onPressed: _abrirModalNovaPromocao,
        backgroundColor: const Color(0xFFE65100),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nova Promoção',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
