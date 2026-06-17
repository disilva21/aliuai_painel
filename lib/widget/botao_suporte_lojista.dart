import 'package:aliuai_painel/chat_suporte_lojista_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 IMPORTAÇÃO DO FIREBASE ADICIONADA SÔ!

class BotaoSuporteLojista extends StatefulWidget {
  final String nomeLoja;
  final String lojaId;
  const BotaoSuporteLojista({super.key, required this.nomeLoja, required this.lojaId});

  @override
  State<BotaoSuporteLojista> createState() => _BotaoSuporteLojistaState();
}

class _BotaoSuporteLojistaState extends State<BotaoSuporteLojista> {
  bool _estaAberto = false; // Controle de abre e fecha sô!

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      // 🛰️ O STREAMBUILDER COMEÇA AQUI ESCUTANDO A PORTA EM TEMPO REAL SÔ!
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('configuracao').doc('ziNL1wNtBbGRWSQHCRzQ').snapshots(),
        builder: (context, snapshot) {
          // Se o Firebase estiver instável ou carregando, a gente não desenha nada sô
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }

          final dadosConfig = snapshot.data!.data() as Map<String, dynamic>?;

          // 🕵️‍♂️ Puxa a flag 'enabled_chat'. Se não achar, o padrão é 'false' por segurança!
          final bool chatHabilitado = dadosConfig?['enabled_chat'] ?? false;

          // 🔥 O SEGREDO BRUTO: Se o chat estiver desligado na nuvem, apaga o widget inteiro sô!
          if (!chatHabilitado) {
            return const SizedBox.shrink();
          }

          // Se estiver true, renderiza a fiação normal que você já tinha feito ó:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 📬 1. A JANELA DO CHAT (Só aparece se estiver aberto sô!)
              if (_estaAberto) ...[
                Container(
                  width: 380, // Largura perfeita para não tapar o painel todo sô!
                  height: 500, // Altura padrão de widget de atendimento
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  // Envelopamos com ClipRRect para os cantos arredondados sô!
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ChatSuporteLojistaPage(
                      nomeLoja: widget.nomeLoja,
                      lojaId: widget.lojaId,
                      onFechar: () {
                        setState(() {
                          _estaAberto = false;
                        });
                      },
                    ),
                  ),
                ),
              ],

              // 🎈 2. O BOTÃO FLUTUANTE QUE CONTROLA O ACESSO SÔ!
              if (!_estaAberto)
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _estaAberto = !_estaAberto;
                    });
                  },
                  backgroundColor: Colors.orange,
                  elevation: 6,
                  shape: const CircleBorder(), // Garante que ele vai ser uma bolinha perfeita sô!
                  // Efeito visual: Se tiver aberto vira um "X", se tiver fechado vira o Balãozinho sô!
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      key: ValueKey<bool>(_estaAberto), // Necessário para a animação funcionar sô!
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
