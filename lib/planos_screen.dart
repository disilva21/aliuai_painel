import 'package:aliuai_painel/admin/pagamento_screen.dart';
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
  String _planoAtual = 'inicial';
  String? _nomeEstabelecimento;

  @override
  void initState() {
    super.initState();
    _buscarPlanoAtual();
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
        return Colors.grey[700]!;
      case 'intermediario':
        return const Color(0xFFE65100);
      case 'master':
        return const Color(0xFF1E1E26);
      default:
        return const Color(0xFFE65100);
    }
  }

  /// Abre a confirmation para o lojista
  void _confirmarMudancaPlano(String nomePlano, String idPlano, double valor, int limite_prod, int limite_promo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Color(0xFFE65100)),
            const SizedBox(width: 12),
            Text('Mudar para o $nomePlano'),
          ],
        ),
        content: Text(
          'Confirma a alteração do seu plano para o $nomePlano (${valor.toStringAsFixed(2).replaceAll('.', ',')}/mês)?\n\n'
          'Seus novos limites serão:\n'
          '• Até $limite_prod produtos cadastrados\n'
          '• Até $limite_promo promoções ativas',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () {
              Navigator.pop(context); // Fecha o modal
              PlanoService.iniciarMudancaDePlano(
                context: context,
                lojaId: widget.lojaId,
                nomeLoja: _nomeEstabelecimento!,
                idNovoPlano: idPlano,
                limiteProd: limite_prod,
                limitePromo: limite_promo,
                valorPlano: valor,
                onLoadingChanged: (carregando) {
                  setState(() => _processandoUpgrade = carregando);
                },
              );
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }

    if (_processandoUpgrade) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE65100)),
            SizedBox(height: 16),
            Text('Configurando seus novos limites no aliuai...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚀 Planos de Assinatura',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            const Text('Escolha o plano ideal para o tamanho e a necessidade do seu estabelecimento.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 40),

            if (_planoAtual == 'indefinido')
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        '🚀  Voce ainda não possui um plano ativo. Por favor, escolha um plano para ativar sua loja no aplicativo.',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // 📡 STREAMBUILDER CONECTADO NA SUA NOVA COLEÇÃO 'PLANOS'
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('planos').where('ativo', isEqualTo: true).orderBy('ordem').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return Center(child: Text('Erro ao carregar planos do banco: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum plano ativo encontrado no banco de dados. 🌐'));
                }

                final planosDocs = snapshot.data!.docs;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: planosDocs.map((doc) {
                    final planoId = doc.id; // ex: 'inicial', 'intermediario', 'master'
                    final dadosPlano = doc.data() as Map<String, dynamic>;

                    // Puxa as informações dinâmicas do documento
                    final String titulo = dadosPlano['nome'] ?? 'Plano';
                    final double valorReal = (dadosPlano['valor'] ?? 0.0).toDouble();
                    final String precoFormatado = valorReal.toStringAsFixed(2).replaceAll('.', ',');

                    final int limiteProd = dadosPlano['limite_produtos'] ?? 0;
                    final int limitePromo = dadosPlano['limite_promocoes'] ?? 0;
                    final bool recomendar = dadosPlano['recomendar'] ?? false;

                    // Converte o Array de benefícios cadastrado no Firebase
                    final List<dynamic> recursosCarregados = dadosPlano['beneficios'] ?? [];
                    final List<String> recursos = recursosCarregados.map((e) => e.toString()).toList();

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0), // Mantém o espaçamento entre cards
                        child: _buildCardPlano(
                          titulo: titulo,
                          preco: precoFormatado,
                          idPlano: planoId,
                          corDestaque: _obterCorDestaque(planoId),
                          recomendar: recomendar,
                          recursos: recursos,
                          descricao: dadosPlano['descricao'] ?? '',
                          onEscolher: () => _confirmarMudancaPlano(titulo, planoId, valorReal, limiteProd, limitePromo),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPlano({
    required String titulo,
    required String preco,
    required String idPlano,
    required Color corDestaque,
    required List<String> recursos,
    required VoidCallback onEscolher,
    required String descricao,
    bool recomendar = false,
  }) {
    bool isPlanoAtual = _planoAtual == idPlano;

    return Stack(
      children: [
        Card(
          elevation: recomendar ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),

            side: BorderSide(color: isPlanoAtual ? corDestaque : (recomendar ? corDestaque.withOpacity(0.5) : Colors.grey[300]!), width: isPlanoAtual ? 3 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            key: ValueKey(idPlano), // Ajuda o Flutter a renderizar a árvore sem perder o foco
            child: Column(
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
                const SizedBox(height: 16),
                // 🚀 ADICIONE ESTE BLOCO AQUI EMBAIXO DO TÍTULO:
                if (descricao.isNotEmpty) ...[const SizedBox(height: 4), Text(descricao, style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3))],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('R\$ ', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(preco, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                    const Text(' /mês', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                Column(
                  children: recursos.map((rec) {
                    bool esgotado = rec.contains('Sem');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Icon(esgotado ? Icons.cancel_outlined : Icons.check_circle_outline_rounded, color: esgotado ? Colors.red[300] : Colors.green[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rec,
                              style: TextStyle(fontSize: 14, color: esgotado ? Colors.grey : Colors.black87, decoration: esgotado ? TextDecoration.lineThrough : null),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),

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
                    onPressed: isPlanoAtual ? null : onEscolher, // Dispara a função de escolher
                    child: Text(
                      isPlanoAtual
                          ? 'Plano Atual'
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
