import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para saber quem é o lojista logado sô!
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatSuporteLojistaPage extends StatefulWidget {
  final String nomeLoja;
  final String lojaId;
  final VoidCallback onFechar; // 👈 Adicionado para fechar a modal pelo título sô!

  const ChatSuporteLojistaPage({
    super.key,
    required this.nomeLoja,
    required this.lojaId,
    required this.onFechar, // 👈 Parâmetro obrigatório agora sô!
  });

  @override
  State<ChatSuporteLojistaPage> createState() => _ChatSuporteLojistaPageState();
}

class _ChatSuporteLojistaPageState extends State<ChatSuporteLojistaPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Guardamos o ID da última mensagem para saber se a que chegou é NOVA sô
  static String _idUltimaMensagemLojista = '';

  // 🔔 2. Função que toca o Bip (Aponte para o mesmo arquivo do som do pedido sô!)
  void _tocarBipMensagem() async {
    try {
      // Exemplo se o som do seu pedido estiver em assets/audio/chat.mp3 sô
      await _audioPlayer.play(AssetSource('sounds/chat.mp3'));
    } catch (e) {
      debugPrint('Erro ao tocar o bip do lojista sô: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Limpa o player quando fechar o chat sô
    super.dispose();
  }

  // 🕵️ O ID único desse lojista logado sô!
  final String? _uidLojista = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _enviarMensagem() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty || _uidLojista == null) return;

    _msgController.clear();
    final agora = Timestamp.now();
    final canalRef = FirebaseFirestore.instance.collection('chats').doc(widget.lojaId);

    // 1. Grava a mensagem dizendo que NÃO foi o admin quem mandou sô!
    await canalRef.collection('mensagens').add({
      'texto': texto,
      'criado_em': agora,
      'remetente_id': widget.lojaId,
      'remetente_user_id': _uidLojista,
      'enviado_por_admin': false, // <-- Aqui tá o segredo sô!
    });

    // 2. Atualiza a capa do chat para o Admin ver a nova mensagem no topo da lista dele sô
    await canalRef.set({'ultima_mensagem': texto, 'ultimo_envio': agora, 'nome_loja': widget.nomeLoja, 'loja_id': widget.lojaId}, SetOptions(merge: true));

    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    if (_uidLojista == null) {
      return const Center(
        child: Text('Você precisa estar logado sô!', style: TextStyle(color: Colors.black)),
      );
    }

    // 🤠 Tiramos o Scaffold bruto e usamos um Container com fundo branco sô!
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // 1. A nossa barra de título customizada (Substitui a AppBar sô!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suporte Aliuai 🤠',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.none),
                  ),
                  GestureDetector(
                    onTap: widget.onFechar,
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // 📬 2. O motor de tempo real sô!
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.lojaId).collection('mensagens').orderBy('criado_em', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Precisa de ajuda sô?\nMande sua dúvida abaixo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final msgs = snapshot.data!.docs;

                // 📬 Dentro do seu StreamBuilder da ChatSuporteLojistaPage:
                if (msgs.isNotEmpty) {
                  final msgTopo = msgs.first;
                  final dadosUltimaMsg = msgTopo.data() as Map<String, dynamic>;
                  final String idMsgAtual = msgTopo.id;
                  final bool enviadoPorAdmin = dadosUltimaMsg['enviado_por_admin'] == true;

                  // 🤠 Primeira carga: Carimba o ID atual e fica quieto sô
                  if (_idUltimaMensagemLojista.isEmpty) {
                    _idUltimaMensagemLojista = idMsgAtual;
                  }
                  // 🔥 Mensagem nova: Se o ID mudou de verdade, atualiza e solta o som!
                  else if (_idUltimaMensagemLojista != idMsgAtual) {
                    _idUltimaMensagemLojista = idMsgAtual; // Atualiza o guardião sô!

                    if (enviadoPorAdmin) {
                      _tocarBipMensagem(); // 🔔 Agora o estalo do Bip vai tocar lindo pro lojista!
                    }
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final dados = msgs[index].data() as Map<String, dynamic>;
                    final enviadoPorAdmin = dados['enviado_por_admin'] == true;

                    // Forçamos o texto a buscar tanto 'texto' quanto 'text' para não ter erro sô!
                    final textoMensagem = dados['texto'] ?? '';

                    return Align(
                      alignment: enviadoPorAdmin ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: enviadoPorAdmin ? Colors.grey[300] : Colors.orange[200], borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          textoMensagem,
                          style: const TextStyle(
                            color: Colors.black, // ⚠️ GARANTE A COR PRETA DO TEXTO SÔ!
                            fontSize: 14,
                            decoration: TextDecoration.none, // Tira sublinhados amarelos feios do Web sô
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✍️ 3. Campo de texto pro Lojista escrever a prosa sô
          Material(
            // Necessário para o TextField não quebrar no Web dentro da modal sô!
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.black),
                      onSubmitted: (valor) {
                        _enviarMensagem();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Digite sua dúvida pro suporte sô...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.orange),
                    onPressed: _enviarMensagem,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
