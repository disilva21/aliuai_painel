import 'package:cloud_firestore/cloud_firestore.dart';

class PagamentoParcial {
  final DateTime dataPagamento;
  final double valorPago;

  PagamentoParcial({required this.dataPagamento, required this.valorPago});

  Map<String, dynamic> toMap() {
    return {'data_pagamento': Timestamp.fromDate(dataPagamento), 'valor_pago': valorPago};
  }

  factory PagamentoParcial.fromMap(Map<String, dynamic> mapa) {
    return PagamentoParcial(dataPagamento: (mapa['data_pagamento'] as Timestamp).toDate(), valorPago: (mapa['valor_pago'] ?? 0.0).toDouble());
  }
}

class DividaFiadoModel {
  final String? id;
  final String lojaId;
  final String clienteId;
  final DateTime dataCompra;
  final String descricao;
  final double valorOriginal;
  final double valorRestante; // 🎯 O campo chave para o abatimento parcial!
  final String status; // 'pendente', 'parcial', 'pago'
  final List<PagamentoParcial> pagamentosParciais;

  DividaFiadoModel({
    this.id,
    required this.lojaId,
    required this.clienteId,
    required this.dataCompra,
    required this.descricao,
    required this.valorOriginal,
    required this.valorRestante,
    required this.status,
    required this.pagamentosParciais,
  });

  Map<String, dynamic> toMap() {
    return {
      'loja_id': lojaId,
      'cliente_id': clienteId,
      'data_compra': Timestamp.fromDate(dataCompra),
      'descricao': descricao,
      'valor_original': valorOriginal,
      'valor_restante': valorRestante,
      'status': status,
      'pagamentos_parciais': pagamentosParciais.map((p) => p.toMap()).toList(),
    };
  }

  factory DividaFiadoModel.fromFirestore(DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;

    var listaPagamentos = <PagamentoParcial>[];
    if (dados['pagamentos_parciais'] != null) {
      listaPagamentos = (dados['pagamentos_parciais'] as List).map((item) => PagamentoParcial.fromMap(item as Map<String, dynamic>)).toList();
    }

    return DividaFiadoModel(
      id: doc.id,
      lojaId: dados['loja_id'] ?? '',
      clienteId: dados['cliente_id'] ?? '',
      dataCompra: dados['data_compra'] != null ? (dados['data_compra'] as Timestamp).toDate() : DateTime.now(),
      descricao: dados['descricao'] ?? '',
      valorOriginal: (dados['valor_original'] ?? 0.0).toDouble(),
      valorRestante: (dados['valor_restante'] ?? 0.0).toDouble(),
      status: dados['status'] ?? 'pendente',
      pagamentosParciais: listaPagamentos,
    );
  }
}
