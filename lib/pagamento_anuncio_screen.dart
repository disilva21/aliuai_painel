import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 🚀 O gerador mágico de QR Code!

class PagamentoAnuncioScreen extends StatelessWidget {
  final String anuncioId;

  const PagamentoAnuncioScreen({super.key, required this.anuncioId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pagamento do Anúncio'),
        backgroundColor: const Color(0xFFE65100), // Laranja AliUai
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Impede o usuário de voltar sem pagar
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔍 Vigia o documento de pagamento atrelado ao nosso anúncio de Classificados sô!
        stream: FirebaseFirestore.instance.collection('pagamentos').where('referenciaId', isEqualTo: anuncioId).where('tipo', isEqualTo: 'classificado').limit(1).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar o pagamento, sô.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE65100)),
                  SizedBox(height: 16),
                  Text(
                    'Gerando fiação do seu PIX...',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Pega o documento do pagamento
          final docPagamento = snapshot.data!.docs.first;
          final dadosPagamento = docPagamento.data() as Map<String, dynamic>;

          final String status = dadosPagamento['status'] ?? 'pendente';
          final String pixCopiaECola = dadosPagamento['pixCopiaECola'] ?? "";

          // 🎉 CASO JÁ ESTIVER CONFIRMADO E PAGO:
          if (status == 'pago') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 100),
                    const SizedBox(height: 24),
                    const Text('Anúncio Publicado!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text(
                      'Seu anúncio já está no ar no AliUai sô! Boas vendas!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // Limpa a navegação e volta para a Home do App
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ir para a Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          // ⏳ SE ESTIVER AGUARDANDO PAGAMENTO (MOSTRA QR CODE E COPIA/COLA):
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pix, color: Color(0xFF00BDF2), size: 50),
                const SizedBox(height: 12),
                const Text(
                  'Falta pouco sô!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Pague o PIX de R\$ 5,99 para ativar seu anúncio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // 🖨️ QUADRO DO QR CODE
                if (pixCopiaECola.isNotEmpty) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: QrImageView(
                        data: pixCopiaECola,
                        version: QrVersions.auto,
                        size: 220.0, // Tamanho ideal para leitura rápida
                        gapless: false,
                        errorStateBuilder: (cxt, err) {
                          return const Center(child: Text('Erro ao gerar QR Code uai!'));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aponte a câmera do seu banco para o QR Code acima',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'Aguardando o banco enviar o QR Code...',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Card de Resumo de Preço
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taxa Única:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        'R\$ 5,99',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 📋 BOTÃO COPIAR E COLA (Caso ele esteja no próprio celular pagando)
                if (pixCopiaECola.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pixCopiaECola));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado! Abra o aplicativo do seu banco.'), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar Código PIX Copia e Cola'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BDF2), // Azul PIX
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Status de sincronização piscando/atualizando
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                    SizedBox(width: 12),
                    Text(
                      'Aguardando confirmação do pagamento...',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}
