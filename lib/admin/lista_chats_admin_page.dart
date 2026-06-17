import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // 🎧 Pacote de som sô!

class ListaChatsAdminPage extends StatefulWidget {
  final Function(String id, String nome) onSelecionarLojista;

  const ListaChatsAdminPage({super.key, required this.onSelecionarLojista});

  @override
  State<ListaChatsAdminPage> createState() => _ListaChatsAdminPageState();
}

class _ListaChatsAdminPageState extends State<ListaChatsAdminPage> {
  // 🔥 Criamos o jogador de áudio sô
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Guardamos o ID da última mensagem para saber se a que chegou agora é realmente NOVA sô
  String _idUltimaMensagemGravada = '';

  void _tocarAlertaSonoro() async {
    try {
      // Você pode colocar um arquivo .mp3 curto na sua pasta assets/audio/ sô!
      // Ex: assets/audio/bip.mp3
      await _audioPlayer.play(AssetSource('sounds/chat.mp3'));
    } catch (e) {
      debugPrint('Erro ao tocar o bip sô: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Limpa a memória sô
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canais de Suporte 🤠'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').orderBy('ultimo_envio', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum lojista chamou ainda sô!'));
          }

          final chats = snapshot.data!.docs;

          // 🚨 O PULO DO GATO PRO CAFÉ: Detecta se chegou mensagem nova no topo!
          if (chats.isNotEmpty) {
            final dadosPrimeiroChat = chats.first.data() as Map<String, dynamic>;
            final String idMensagemAtual = dadosPrimeiroChat['ultimo_envio']?.toString() ?? '';

            if (_idUltimaMensagemGravada.isNotEmpty && _idUltimaMensagemGravada != idMensagemAtual) {
              _tocarAlertaSonoro();
            }
            _idUltimaMensagemGravada = idMensagemAtual;
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final dados = chats[index].data() as Map<String, dynamic>;
              final String idLojista = chats[index].id;
              final String nomeLoja = dados['nome_loja'] ?? 'Loja sem Nome';
              final String ultimaMsg = dados['ultima_mensagem'] ?? 'Sem mensagens';

              final bool temMensagemNova = dados['enviado_por_admin'] == false;
              // 🕵️ Buscando a marcação de prioridade no banco sô!
              // final bool ehPrioritario = dados['prioritario'] == true;

              return Container(
                // 🔴 MARCAÇÃO VISUAL: Se for prioritário, ganha uma borda vermelha ou fundo suave sô!
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  // color: temMensagemNova ? Colors.orange.withOpacity(0.05) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: temMensagemNova ? Border.all(color: Colors.redAccent, width: 1.5) : null,
                ),
                child: ListTile(
                  tileColor: temMensagemNova ? Colors.orange.withOpacity(0.05) : Colors.transparent,
                  leading: Stack(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.store, color: Colors.white),
                      ),
                      if (temMensagemNova)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green, // Bolinha verde de "Online/Nova" sô!
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2), // Bordinha branca chique
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    nomeLoja,
                    style: TextStyle(fontWeight: temMensagemNova ? FontWeight.bold : FontWeight.normal, color: temMensagemNova ? Colors.black : Colors.grey[800]),
                  ),
                  subtitle: Text(
                    ultimaMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: temMensagemNova ? FontWeight.w600 : FontWeight.normal, color: temMensagemNova ? Colors.orange[800] : Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (temMensagemNova)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
                          child: const Text(
                            'NOVA',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () async {
                    widget.onSelecionarLojista(idLojista, nomeLoja);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
