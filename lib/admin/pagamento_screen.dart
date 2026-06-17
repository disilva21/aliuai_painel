import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutPixScreen extends StatelessWidget {
  final String pagamentoId;

  const CheckoutPixScreen({super.key, required this.pagamentoId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF5F5F5),
      clipBehavior: Clip.antiAlias,

      child: SizedBox(
        width: 500,
        height: 650,
        child: Column(
          children: [
            Container(
              height: 50,
              color: Colors.white,
              width: double.infinity,
              // border: const Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
              child: const Center(
                child: Text(
                  'Pagamento do Plano',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                // 📡 Escuta em tempo real o documento específico desta cobrança
                stream: FirebaseFirestore.instance.collection('pagamentos').doc(pagamentoId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
                  }

                  if (snapshot.hasError) {
                    print(snapshot.error);
                    return Center(child: Text('Erro ao carregar devedores sô: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('Não foi possível carregar os dados do pagamento. 😢'));
                  }

                  // Puxa os dados do documento
                  final dados = snapshot.data!.data() as Map<String, dynamic>;
                  final dadosPix = dados['pix'] != null ? Map<String, dynamic>.from(dados['pix']) : {};
                  final String status = dados['status'] ?? 'aguardando_pagamento';
                  final double valor = (dados['valor'] ?? 0.0).toDouble();

                  final String copiaECola = dadosPix['copiaECola'] ?? '';
                  final String qrCodeBase64 = dadosPix['qrCodeBase64'] ?? '';

                  // =========================================================================
                  // ESTADO 1: O documento foi criado, mas o Node/Efí ainda estão gerando o PIX
                  // =========================================================================
                  if (status == 'pendente') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFFE65100)),
                            const SizedBox(height: 24),
                            const Text(
                              'Gerando seu PIX dinâmico...',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Conectando com a API da Efí Bank para processar R\$ ${valor.toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // =========================================================================
                  // ESTADO 2: O Webhook rodou, o backend alterou para "pago". Sucesso total!
                  // =========================================================================
                  if (status == 'pago') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 100),
                            const SizedBox(height: 24),
                            const Text('¡Pagamento Confirmado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'Seus novos limites já estão ativos, sô!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 220,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  // Dá o pop duplo ou joga de volta para a Dashboard atualizada
                                  Navigator.pop(context);
                                },
                                child: const Text('Ir para o Painel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // =========================================================================
                  // ESTADO 3: PIX gerado com sucesso, exibindo o QR Code e o Copia e Cola
                  // =========================================================================

                  // Trata e decodifica os bytes da imagem PNG em Base64 fornecida pela Efí
                  final String base64Limpo = qrCodeBase64.contains(',') ? qrCodeBase64.split(',').last : qrCodeBase64;
                  final Uint8List qrCodeBytes = base64Decode(base64Limpo);

                  return Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Escaneie o QR Code abaixo:', style: TextStyle(color: Colors.grey, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${valor.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                            ),
                            const SizedBox(height: 20),

                            // Box da Imagem do QR Code decodificada da Efí
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Image.memory(qrCodeBytes, width: 250, height: 250, fit: BoxFit.contain),
                            ),

                            const SizedBox(height: 20),
                            // Indicador discreto de que o app está esperando o banco avisar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[600])),
                                const SizedBox(width: 10),
                                Text('Aguardando aprovação do banco...', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // Botão PIX Copia e Cola
                            SizedBox(
                              width: double.infinity,

                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E26),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copiar Código PIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: copiaECola));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código Pix Copia e Cola copiado! 📋'), backgroundColor: Colors.green));
                                },
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Botão de desistência / Cancelamento manual
                            TextButton(
                              onPressed: () async {
                                // 1. Abre um alerta rápido de confirmação
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Cancelar Cobrança? 🛑'),
                                    content: const Text('Se você voltar, este QR Code PIX será cancelado.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar no PIX')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                        onPressed: () async {
                                          Navigator.pop(context); // Fecha a janelinha de alerta

                                          // 2. Avisa o Firestore que o lojista desistiu daquele PIX
                                          await FirebaseFirestore.instance.collection('pagamentos').doc(pagamentoId).update({'status': 'cancelado'});

                                          // 3. Destrói o Checkout e volta direto para a tela de Planos!
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Sim, Cancelar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Text(
                                'Cancelar e Escolher Outro Plano',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
