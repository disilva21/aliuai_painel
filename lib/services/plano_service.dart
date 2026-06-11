import 'package:cloud_firestore/cloud_firestore.dart';

class PlanoService {
  // 🔥 MÉTODO GLOBAL AJUSTADO: Agora ele retorna o ID gerado ou null se der erro sô!
  static Future<String?> iniciarMudancaDePlano({
    required String lojaId,
    required String nomeLoja,
    required String idNovoPlano,
    required int limiteProd,
    required int limitePromo,
    required double valorPlano,
  }) async {
    try {
      final agora = DateTime.now();
      final proximoVencimento = agora.add(const Duration(days: 30));

      // 1. 💾 Grava o documento na coleção de pagamentos
      final docRef = await FirebaseFirestore.instance.collection('pagamentos').add({
        'loja_id': lojaId,
        'valor': valorPlano,
        'nomeEstabelecimento': nomeLoja,
        'status': valorPlano == 0 ? 'gratis' : 'pendente', // Se for R$ 0, já marca como gratis sô!
        'plano_pretendido': {'nome': idNovoPlano, 'limite_produtos': limiteProd, 'limite_promocoes': limitePromo},
        'criadoEm': FieldValue.serverTimestamp(),
      });

      // 2. 🎯 SE FOR PLANO GRÁTIS: Já faz o papel da Function direto por aqui
      if (valorPlano == 0) {
        final nomePlanoLimpo = idNovoPlano.toLowerCase().replaceAll('plano ', '');

        await FirebaseFirestore.instance.collection('estabelecimentos').doc(lojaId).update({
          'plano_atual': nomePlanoLimpo,
          'limite_produtos': limiteProd,
          'limite_promocoes': limitePromo,
          'status_pagamento': 'em_dia',
          'ativo': true,
          'pagoEm': agora.toIso8601String(),
          'proximo_vencimento': proximoVencimento.toIso8601String(),
        });
      }

      // Devolve o ID do pagamento gerado com sucesso!
      return docRef.id;
    } catch (e) {
      print('Erro no PlanoService sô: $e');
      return null;
    }
  }
}
