import 'package:aliuai_painel/checkout_pix_screen.dart';
import 'package:aliuai_painel/services/plano_service.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanosScreen extends StatefulWidget {
  final String lojaId; // ✨ Recebe o ID automático garantido pela Dashboard

  const PlanosScreen({super.key, required this.lojaId});

  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _carregando = true;
  bool _processandoUpgrade = false;
  String _planoAtual = 'indefinido';
  String? _nomeEstabelecimento;

  // 🔥 NOVAS VARIÁVEIS DE CONTROLE PARA O PIX INTEGRADO NA TELA SÔ!
  bool _mostrarPix = false;
  String _idPagamentoGerado = '';

  @override
  void initState() {
    super.initState();
    _buscarPlanoAtual();
  }

  // Criamos o widget dinâmico de preço sô:
  Widget _construirPreco(double valorPromocional, double valorOriginal) {
    // CASO 1: Tem promoção activa (maior que zero e menor que o original)
    if (valorPromocional > 0 && valorPromocional < valorOriginal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Valor original riscado sô!
              Text(
                'R\$ ${valorOriginal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough, // 🔥 Aqui tá o risco!
                ),
              ),
              const SizedBox(width: 8),
              // Selo discreto de desconto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE65100).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  'PROMO',
                  style: TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Valor promocional grande sô!
          Text(
            'R\$ ${valorPromocional.toStringAsFixed(2)}/mês',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
          ),
          const Text(
            'por 30 dias, depois valor normal',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    // CASO 2: É de graça! (valor_promocional é 0)
    if (valorPromocional == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'R\$ ${valorOriginal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough, // 🔥 Riscado também!
            ),
          ),
          const SizedBox(height: 4),
          // Destaca o GRÁTIS em verde bem bonito sô!
          const Text(
            'GRÁTIS',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Text(
            'Experimente por 30 dias sem pagar nada!',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    // CASO 3: Sem promoção (mostra o valor padrão normal sô)
    return Text(
      'R\$ ${valorOriginal.toStringAsFixed(2)}/mês',
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
    );
  }

  /// Puxa o plano que está salvo atualmente no banco
  Future<void> _buscarPlanoAtual() async {
    try {
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      if (docLoja.exists && mounted) {
        setState(() {
          _planoAtual = docLoja.data()?['plano_atual'] ?? 'indefinido';
          _carregando = false;
          _nomeEstabelecimento = docLoja.data()?['nome'] ?? 'Estabelecimento';
        });
      }
    } catch (e) {
      print('Erro ao buscar plano atual: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// 🎨 Define a cor de destaque correta de acordo com o ID do plano cadastrado no Firebase
  Color _obterCorDestaque(String idPlano) {
    switch (idPlano) {
      case 'inicial':
        return const Color(0xFFE65100);
      case 'intermediario':
        return const Color(0xFFE65100);
      case 'master':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFFE65100);
    }
  }

  /// Abre a confirmação para o lojista e integra com o fluxo novo sô!
  void _confirmarMudancaPlano(String nomePlano, String idPlano, double valor, double valorPromocional, int limite_prod, int limite_promo) {
    final valorPlano = valorPromocional < valor ? valorPromocional : valor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.rocket_launch, color: Color(0xFFE65100)),
            SizedBox(width: 12),
            Text('Mudar de Plano'),
          ],
        ),
        content: Text('Confirma a alteração do seu plano para o $nomePlano (${valorPlano.toStringAsFixed(2).replaceAll('.', ',')}/mês)?\n\n'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () async {
              Navigator.pop(context); // Fecha a janelinha do confirmation sô!

              setState(() => _processandoUpgrade = true); // Liga o seu loading verde

              // 🚀 Aciona o PlanoService que devolve apenas o ID gerado!
              final String? idGerado = await PlanoService.iniciarMudancaDePlano(
                lojaId: widget.lojaId,
                nomeLoja: _nomeEstabelecimento!,
                idNovoPlano: idPlano,
                limiteProd: limite_prod,
                limitePromo: limite_promo,
                valorPlano: valorPlano,
              );

              if (mounted) setState(() => _processandoUpgrade = false); // Desliga o load

              if (idGerado != null && mounted) {
                // Se o plano contratado for PAGO (maior que 0), ativa a tela do Pix sô!
                if (valorPlano > 0) {
                  setState(() {
                    _idPagamentoGerado = idGerado;
                    _mostrarPix = true; // 🔥 Chaveia o layout para exibir o Pix!
                  });
                } else {
                  // Se for grátis, o próprio service já rodou o update e soltou o SnackBar sô.
                  // Vamos só atualizar o plano atual na tela para o lojista ver!
                  _buscarPlanoAtual();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao processar alteração do plano sô!'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Confirmar Alteração', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 19, 7, 0)));
    }

    if (_processandoUpgrade) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color.fromARGB(255, 0, 230, 12)),
            SizedBox(height: 16),
            Text('Configurando seus novos limites no aliuai...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // 🎯 INTEGRADO: SE O PIX ESTIVER ATIVADO, RENDERIZA ELE DIRETO NO CORPO SÔ!
    if (_mostrarPix) {
      return CheckoutPixScreen(
        pagamentoId: _idPagamentoGerado,
        onVoltar: () {
          setState(() {
            _mostrarPix = false; // Desativa e volta para a lista dinâmica
          });
          _buscarPlanoAtual(); // Dá um refresh no plano atual sô!
        },
      );
    }

    // 🖥️ Captura o tamanho da tela para aplicar a responsividade cirúrgica sô!
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Mantido fundo limpo sô
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚀 Planos de Assinatura',
              style: TextStyle(fontSize: ehCelular ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha o plano ideal para o tamanho e a necessidade do seu estabelecimento.',
              style: TextStyle(color: Colors.grey, fontSize: ehCelular ? 13 : 14),
            ),
            SizedBox(height: ehCelular ? 24 : 40),

            if (_planoAtual == 'indefinido')
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        '🚀  Você ainda não possui um plano ativo. Por favor, escolha um plano para ativar sua loja no aplicativo.',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // 📡 SEU STREAMBUILDER DO FIREBASE CONTINUA TOTALMENTE VIVO E DINÂMICO SÔ!
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('planos').where('ativo', isEqualTo: true).orderBy('ordem').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar planos do banco: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum plano ativo encontrado no banco de dados. 🌐'));
                }

                final planosDocs = snapshot.data!.docs;

                // Layout para Computador (3 Colunas Lado a Lado sô)
                if (!ehCelular) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10.0, mainAxisSpacing: 15.0, childAspectRatio: 0.52),
                    itemCount: planosDocs.length,
                    itemBuilder: (context, index) {
                      final doc = planosDocs[index];
                      return _montarCardDoDoc(doc, ehCelular);
                    },
                  );
                }

                // Layout para Celular (Lista Vertical)
                return Column(
                  children: planosDocs.map((doc) {
                    return Padding(padding: const EdgeInsets.only(bottom: 20.0), child: _montarCardDoDoc(doc, ehCelular));
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ⚙️ Função auxiliar isolada para extrair os dados do documento do Firebase e montar o card
  Widget _montarCardDoDoc(DocumentSnapshot doc, bool ehCelular) {
    final planoId = doc.id;
    final dadosPlano = doc.data() as Map<String, dynamic>;

    final String titulo = dadosPlano['nome'] ?? 'Plano';
    final double valorReal = (dadosPlano['valor'] ?? 0.0).toDouble();
    final double valorPromocional = (dadosPlano['valor_promocional'] ?? 0.0).toDouble();

    final int limiteProd = dadosPlano['limite_produtos'] ?? 0;
    final int limitePromo = dadosPlano['limite_promocoes'] ?? 0;
    final bool recomendar = dadosPlano['recomendar'] ?? false;

    final List<dynamic> recursosCarregados = dadosPlano['beneficios'] ?? [];
    final List<String> recursos = recursosCarregados.map((e) => e.toString()).toList();

    return _buildCardPlano(
      titulo: titulo,
      valorOriginal: valorReal,
      valorPromocional: valorPromocional,
      idPlano: planoId,
      corDestaque: _obterCorDestaque(planoId),
      recomendar: recomendar,
      recursos: recursos,
      descricao: dadosPlano['descricao'] ?? '',
      ehCelular: ehCelular,
      onEscolher: () => _confirmarMudancaPlano(titulo, planoId, valorReal, valorPromocional, limiteProd, limitePromo),
    );
  }

  Widget _buildCardPlano({
    required String titulo,
    required double valorOriginal,
    required double valorPromocional,
    required String idPlano,
    required Color corDestaque,
    required List<String> recursos,
    required VoidCallback onEscolher,
    required String descricao,
    required bool ehCelular,
    bool recomendar = false,
  }) {
    bool isPlanoAtual = _planoAtual == idPlano;

    return Stack(
      children: [
        Card(
          color: Colors.white,
          elevation: recomendar ? 4 : 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isPlanoAtual ? corDestaque : (recomendar ? corDestaque.withOpacity(0.5) : Colors.grey[300]!), width: isPlanoAtual ? 3 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            key: ValueKey(idPlano),
            // 🔥 CORRIGIDO SÔ: Tiramos o SizedBox(height: double.infinity) que quebrava o Mobile!
            child: Column(
              mainAxisSize: MainAxisSize.min, // Faz o card abraçar o conteúdo no celular sô!
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPlanoAtual)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: corDestaque.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'Seu Plano Ativo ✔',
                      style: TextStyle(color: corDestaque, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (descricao.isNotEmpty) ...[const SizedBox(height: 6), Text(descricao, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3))],
                const SizedBox(height: 16),

                // 🔥 RENDERIZA O VALOR COM A REGRA DO PREÇO RISCADO DINÂMICO SÔ!
                _construirPreco(valorPromocional, valorOriginal),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Lista de recursos vinda da collection planos sô!
                Column(
                  children: recursos.map((rec) {
                    bool esgotado = rec.contains('Sem');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(esgotado ? Icons.cancel_outlined : Icons.check_circle_outline_rounded, color: esgotado ? Colors.red[300] : Colors.green[600], size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rec,
                              style: TextStyle(fontSize: 13, color: esgotado ? Colors.grey : Colors.black87, decoration: esgotado ? TextDecoration.lineThrough : null),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // 🎯 PULO DO GATO: O Spacer só empurra o botão para o rodapé na Web. No celular, usamos um espaço fixo!
                if (!ehCelular) const Spacer() else const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isPlanoAtual ? Colors.grey[100] : (recomendar ? corDestaque : Colors.transparent),
                      side: BorderSide(color: isPlanoAtual ? Colors.grey[300]! : corDestaque),
                      foregroundColor: isPlanoAtual ? Colors.grey[600] : (recomendar ? Colors.white : corDestaque),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isPlanoAtual ? null : onEscolher,
                    child: Text(
                      isPlanoAtual
                          ? 'Plano Ativo'
                          : _planoAtual == 'indefinido'
                          ? 'Escolher Plano'
                          : 'Migrar de Plano',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (recomendar && !isPlanoAtual)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: corDestaque, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'RECOMENDADO',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
