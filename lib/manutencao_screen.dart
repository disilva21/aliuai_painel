import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ManutencaoScreen extends StatelessWidget {
  final String whatsappAdmin;
  const ManutencaoScreen({super.key, required this.whatsappAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🚜 Ícone bruto do trator na oficina sô!
              const Icon(Icons.construction_rounded, size: 80, color: Color(0xFFE65100)),
              const SizedBox(height: 24),
              const Text(
                'Trator na Oficina sô! 🚜🔧',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
              ),
              const SizedBox(height: 16),
              const Text(
                'O painel do AliUai está passando por uma manutenção rápida para regular as máquinas e engraxar as engrenagens. Voltamos num pulo, sô!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 32),
              // ☕ Um loading chique indicando progresso
              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFFE65100), strokeWidth: 3)),
              const SizedBox(height: 40),
              // Botão de socorro se o lojista estiver desesperado uai
              OutlinedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse('https://wa.me/$whatsappAdmin'); // 📱 Seu Zap de admin sô!
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE65100)),
                  foregroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Falar com o Suporte do AliUai'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
