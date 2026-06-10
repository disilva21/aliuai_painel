import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  static void mostrar(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Força o lojista a ver os passos sô!
      builder: (context) => const OnboardingDialog(),
    );
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  int _passoAtual = 0;

  // 📝 Lista com todas as suas instruções estruturadas em passos
  final List<Map<String, dynamic>> _passos = [
    {
      'icone': Icons.person_outline_rounded,
      'titulo': 'Complete seu Perfil',
      'descricao': 'Finalize seu cadastro agora mesmo clicando no menu "Meu Perfil" no menu lateral sô! Isso garante que seus clientes vejam suas informações certinhas.',
    },
    {
      'icone': Icons.card_membership_rounded,
      'titulo': 'Escolha seu Plano',
      'descricao': 'Escolha o plano que melhor atende a necessidade do seu negócio e destrave todos os recursos premium do aliuai.',
    },
    {
      'icone': Icons.fastfood_rounded,
      'titulo': 'Cadastre seus Produtos',
      'descricao': 'Hora de abastecer sua vitrine! Cadastre seus produtos, fotos e crie promoções irresistíveis para bombar o faturamento.',
    },
    {
      'icone': Icons.receipt_long_rounded,
      'titulo': 'Acompanhe seus Pedidos',
      'descricao': 'Fique de olho na tela! Sempre que um cliente pedir pela mesa ou WhatsApp, o pedido vai apitar aqui em tempo real.',
    },
    {
      'icone': Icons.calendar_month_rounded,
      'titulo': 'Não esqueça os Eventos! 🗓️',
      'descricao': 'Ah, não se esqueça de cadastrar seus eventos e feiras na agenda! É a melhor forma de avisar seus clientes onde você estará.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final passo = _passos[_passoAtual];
    final bool ehOUltimoPasso = _passoAtual == _passos.length - 1;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E26), // Fundo escuro oficial da marca
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🏷️ Cabeçalho com a logo estilizada aliuai
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    children: const [
                      TextSpan(
                        text: 'ali',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'uai',
                        style: TextStyle(color: Color(0xFFE65100)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seja muito bem-vindo sô! 🎉',
              style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),

            // AnimatedSwitcher para dar um efeito suave de transição entre os passos sô!
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey<int>(_passoAtual),
                children: [
                  // Ícone animado em círculo laranja
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0x1AE65100), // Laranja com opacidade
                      shape: BoxShape.circle,
                    ),
                    child: Icon(passo['icone'], color: const Color(0xFFE65100), size: 48),
                  ),
                  const SizedBox(height: 24),

                  // Título do Passo
                  Text(
                    passo['titulo'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Descrição das Instruções
                  Text(
                    passo['descricao'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 🎹 Indicador de bolinhas (Dots) de progresso
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_passos.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _passoAtual == index ? 24 : 8,
                  decoration: BoxDecoration(color: _passoAtual == index ? const Color(0xFFE65100) : Colors.grey[700], borderRadius: BorderRadius.circular(4)),
                );
              }),
            ),
            const SizedBox(height: 32),

            // 🔘 Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botão de Voltar (Sobe apenas se não estiver no primeiro passo)
                _passoAtual > 0
                    ? TextButton(
                        onPressed: () => setState(() => _passoAtual--),
                        child: Text(
                          'Voltar',
                          style: GoogleFonts.poppins(color: Colors.grey[400], fontWeight: FontWeight.w600),
                        ),
                      )
                    : const SizedBox.shrink(),

                // Botão Avançar / Concluir
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (ehOUltimoPasso) {
                      Navigator.pop(context); // Fecha o guia
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tudo pronto! Vamos faturar! 🚀'), backgroundColor: Colors.green));
                    } else {
                      setState(() => _passoAtual++);
                    }
                  },
                  child: Text(ehOUltimoPasso ? 'Bora começar!' : 'Avançar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
