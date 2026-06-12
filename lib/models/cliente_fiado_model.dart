import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteFiadoModel {
  final String id;
  final String lojaId;
  final String nome;
  final String telefone;
  final double saldoDevedor; // Saldo consolidado para busca rápida sô
  final DateTime? atualizadoEm;

  ClienteFiadoModel({required this.id, required this.lojaId, required this.nome, required this.telefone, required this.saldoDevedor, this.atualizadoEm});

  Map<String, dynamic> toMap() {
    return {
      'loja_id': lojaId,
      'nome': nome,
      'telefone': telefone,
      'saldo_devedor': saldoDevedor,
      'atualizado_em': atualizadoEm != null ? Timestamp.fromDate(atualizadoEm!) : FieldValue.serverTimestamp(),
    };
  }

  factory ClienteFiadoModel.fromFirestore(DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;
    return ClienteFiadoModel(
      id: doc.id,
      lojaId: dados['loja_id'] ?? '',
      nome: dados['nome'] ?? '',
      telefone: dados['telefone'] ?? '',
      saldoDevedor: (dados['saldo_devedor'] ?? 0.0).toDouble(),
      atualizadoEm: (dados['atualizado_em'] as Timestamp?)?.toDate(),
    );
  }
}
