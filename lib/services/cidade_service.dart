import 'package:cloud_firestore/cloud_firestore.dart';

class CidadeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 📡 Escuta em tempo real as cidades cadastradas no AliUai
  Stream<Map<String, bool>> streamCidadesCadastradasStatus() {
    return _firestore.collection('cidades').snapshots().map((snapshot) {
      final Map<String, bool> mapaCidades = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Salva o ID da cidade e se ela está ativa (true) ou inativa (false)
        mapaCidades[doc.id] = data['ativo'] ?? false;
      }
      return mapaCidades;
    });
  }

  // 💾 Salva uma nova cidade na cobertura do app
  Future<void> ativarCidade(String id, String nome, String uf) async {
    await _firestore.collection('cidades').doc(id).set({
      'id': id,
      'nome': nome,
      'uf': uf,
      'ativo': true, // Garante que a porteira tá aberta uai!
      'atualizado_em': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 🗑️ Remove uma cidade da cobertura do app
  Future<void> desativarCidade(String id) async {
    await _firestore.collection('cidades').doc(id).update({
      'ativo': false, // Só fecha o cadeado, mas o documento continua lá!
    });
  }
}
