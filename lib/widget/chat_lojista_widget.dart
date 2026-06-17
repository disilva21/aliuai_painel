import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // 🎧 Importa o tocador de som sô!

class ChatLojistaWidget extends StatefulWidget {
  final String idLojista;
  final String nomeLoja;
  final VoidCallback onVoltar;

  const ChatLojistaWidget({super.key, required this.idLojista, required this.nomeLoja, required this.onVoltar});

  @override
  State<ChatLojistaWidget> createState() => _ChatLojistaWidgetState();
}

class _ChatLojistaWidgetState extends State<ChatLojistaWidget> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 🕹️ Instancia o tocador de som do Admin e o guardião de IDs sô!
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _idUltimaMensagemAdmin = '';

  // 🔔 Função que toca o bip no painel do Admin
  void _tocarBipMensagemAdmin() async {
    try {
      // Aponta para o mesmo arquivo de som que você usa sô!
      await _audioPlayer.play(AssetSource('sounds/chat.mp3'));
    } catch (e) {
      debugPrint('Erro ao tocar o bip do admin sô: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Limpa o player da memória sô!
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🚀 Função bruta para mandar a mensagem sô!
  Future<void> _enviarMensagem() async {
    final texto = _msgController.text.trim();
    if (texto.isEmpty) return;

    _msgController.clear();

    final agora = Timestamp.now();
    final canalRef = FirebaseFirestore.instance.collection('chats').doc(widget.idLojista);

    // 1. Grava a mensagem na subcoleção sô!
    await canalRef.collection('mensagens').add({
      'texto': texto,
      'criado_em': agora,
      'remetente_id': 'admin', // Identifica que foi você quem mandou
      'enviado_por_admin': true,
    });

    // 2. Atualiza a capa do chat para aparecer na lista de conversas
    await canalRef.set({'ultima_mensagem': texto, 'ultimo_envio': agora, 'nome_loja': widget.nomeLoja}, SetOptions(merge: true));

    // Rola a tela para baixo sô
    _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Atendimento: ${widget.nomeLoja} 🤠'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onVoltar),
      ),
      body: Column(
        children: [
          // 📬 STREAMBUILDER: O motor do tempo real sô!
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.idLojista)
                  .collection('mensagens')
                  .orderBy('criado_em', descending: true) // Traz as mais novas primeiro sô
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snapshot.hasError) {
                  print(snapshot.error);
                  return const Center(child: Text('Erro ao carregar os dados ChatLojistaWidget.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhuma mensagem por aqui sô... puxa uma cadeira e comece a prosa!'));
                }

                final msgs = snapshot.data!.docs;

                // 🚨 O PULO DO GATO PRO BIP DO ADMIN NO WEB SÔ!
                if (msgs.isNotEmpty) {
                  final msgTopo = msgs.first;
                  final dadosUltimaMsg = msgTopo.data() as Map<String, dynamic>;
                  final String idMsgAtual = msgTopo.id;
                  final bool enviadoPorLojista = dadosUltimaMsg['enviado_por_admin'] == false;

                  // 🤠 Carga inicial: Conhece o ID antigo e fica quieto para não dar eco.
                  if (_idUltimaMensagemAdmin.isEmpty) {
                    _idUltimaMensagemAdmin = idMsgAtual;
                  }
                  // 🔥 Mudança real: Se o ID mudou e foi o Lojista quem mandou, solta o som!
                  else if (_idUltimaMensagemAdmin != idMsgAtual) {
                    _idUltimaMensagemAdmin = idMsgAtual; // Atualiza o guardião sô!

                    if (enviadoPorLojista) {
                      _tocarBipMensagemAdmin(); // 🔔 Bip do café!
                    }
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Começa de baixo sô!
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final dados = msgs[index].data() as Map<String, dynamic>;
                    final souEu = dados['enviado_por_admin'] == true;

                    return Align(
                      alignment: souEu ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: souEu ? Colors.orange[200] : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                        child: Text(dados['texto'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 14)),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✍️ Campo de texto para digitar a prosa
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(hintText: 'Digite sua mensagem sô...', border: OutlineInputBorder()),
                    onSubmitted: (valor) {
                      _enviarMensagem();
                    },
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
        ],
      ),
    );
  }
}
