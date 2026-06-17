import 'package:aliuai_painel/widget/chat_lojista_widget.dart';
import 'package:flutter/material.dart';
import 'lista_chats_admin_page.dart';

class CentralSuporteAdminAba extends StatefulWidget {
  final String? idLojistaInicial; // 🚀 NOVO: Parâmetro opcional de atalho sô!
  final String? nomeLojaInicial; // 🚀 NOVO: Parâmetro opcional de atalho sô!

  const CentralSuporteAdminAba({super.key, this.idLojistaInicial, this.nomeLojaInicial});

  @override
  State<CentralSuporteAdminAba> createState() => _CentralSuporteAdminAbaState();
}

class _CentralSuporteAdminAbaState extends State<CentralSuporteAdminAba> {
  String? _idLojistaSelecionado;
  String? _nomeLojaSelecionada;

  @override
  void initState() {
    super.initState();
    // Se a aba nascer com dados passados pela tela mãe, engata o chat na hora sô!
    _idLojistaSelecionado = widget.idLojistaInicial;
    _nomeLojaSelecionada = widget.nomeLojaInicial;
  }

  @override
  void didUpdateWidget(covariant CentralSuporteAdminAba oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ⚡ CRÍTICO PARA MODO RELEASE/DEBUG: Se a tela mãe mandar um lojista novo por atalho,
    // intercepta a alteração e atualiza o estado interno na mesma hora uai!
    if (widget.idLojistaInicial != oldWidget.idLojistaInicial) {
      setState(() {
        _idLojistaSelecionado = widget.idLojistaInicial;
        _nomeLojaSelecionada = widget.nomeLojaInicial;
      });
    }
  }

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
