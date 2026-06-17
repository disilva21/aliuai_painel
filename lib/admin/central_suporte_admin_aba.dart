import 'package:aliuai_painel/widget/chat_lojista_widget.dart';
import 'package:flutter/material.dart';
import 'lista_chats_admin_page.dart'; // Sua tela de lista sô

class CentralSuporteAdminAba extends StatefulWidget {
  const CentralSuporteAdminAba({super.key});

  @override
  State<CentralSuporteAdminAba> createState() => _CentralSuporteAdminAbaState();
}

class _CentralSuporteAdminAbaState extends State<CentralSuporteAdminAba> {
  String? _idLojistaSelecionado;
  String? _nomeLojaSelecionada;

  @override
  Widget build(BuildContext context) {
    // 🔄 Se NÃO tiver lojista selecionado, mostra a lista sô!
    if (_idLojistaSelecionado == null) {
      return ListaChatsAdminPage(
        // 🧭 Esse callback vai receber os dados quando você clicar na lista sô!
        onSelecionarLojista: (id, nome) {
          setState(() {
            _idLojistaSelecionado = id;
            _nomeLojaSelecionada = nome;
          });
        },
      );
    }

    // 💬 Se TIVER lojista selecionado, troca o miolo pelo chat sô!
    return ChatLojistaWidget(
      idLojista: _idLojistaSelecionado!,
      nomeLoja: _nomeLojaSelecionada!,
      onVoltar: () {
        setState(() {
          _idLojistaSelecionado = null; // Limpa o ID e o miolo volta a ser a lista sô!
        });
      },
    );
  }
}
