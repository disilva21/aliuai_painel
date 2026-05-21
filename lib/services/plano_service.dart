import 'package:aliuai_painel/admin/pagamento_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Garanta a importação correta da sua tela de Checkout

class PlanoService {
  // 🔥 O MÉTODO GLOBAL E COMPARTILHADO
  static Future<void> iniciarMudancaDePlano({
    required BuildContext context,
    required String lojaId,
    required String nomeLoja,
    required String idNovoPlano,
    required int limiteProd,
    required int limitePromo,
    required double valorPlano,
    required Function(bool) onLoadingChanged, // Callback para avisar a tela se está carregando ou não
  }) async {
    // Avisa a tela que começou a processar (substitui o setState local)
    onLoadingChanged(true);

    // 1. Abre o loading na tela usando o context recebido
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
    );

    try {
      // 2. 💾 Grava o documento na coleção de pagamentos
      final docRef = await FirebaseFirestore.instance.collection('pagamentos').add({
        'loja_id': lojaId,
        'valor': 0.01, //TODO: MUDAR O VALOR FIXO PARA O VALOR DO PLANO SELECIONADO
        'nomeEstabelecimento': nomeLoja,
        'status': 'pendente',
        'plano_pretendido': {'nome': idNovoPlano, 'limite_produtos': limiteProd, 'limite_promocoes': limitePromo},
        'criadoEm': FieldValue.serverTimestamp(),
      });

      // Se o usuário fechou a tela no meio do caminho, para aqui
      if (!context.mounted) return;

      // Fecha o modal de CircularProgressIndicator
      Navigator.pop(context);

      // 3. 🚀 Redireciona para a tela de checkout passando o ID gerado
      Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutPixScreen(pagamentoId: docRef.id)));

      // Avisa a tela que terminou com sucesso
      onLoadingChanged(false);
    } catch (e) {
      // Se der erro, garante fechar o loading se ele ainda estiver aberto
      if (context.mounted) {
        Navigator.pop(context); // Fecha o dialog de erro
        onLoadingChanged(false);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao iniciar processo de pagamento: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
