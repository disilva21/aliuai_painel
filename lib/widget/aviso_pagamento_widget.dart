import 'package:flutter/material.dart';

class AvisoPagamentoWidget extends StatelessWidget {
  final String statusPagamento;
  final VoidCallback onCliqueAction;

  const AvisoPagamentoWidget({super.key, required this.statusPagamento, required this.onCliqueAction});

  @override
  Widget build(BuildContext context) {
    // Se estiver em dia, não precisa mostrar banner nenhum!
    if (statusPagamento == 'em_dia') return const SizedBox.shrink();

    final isAtrasado = statusPagamento == 'atrasado';

    return InkWell(
      onTap: onCliqueAction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        // Vermelho se estiver atrasado, Laranja se estiver pendente (aviso prévio)
        color: isAtrasado ? Colors.red[700] : Colors.orange[700],
        child: Row(
          children: [
            Icon(isAtrasado ? Icons.gavel_rounded : Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAtrasado ? 'MENSALIDADE ATRASADA - Evite o bloqueio da sua conta!' : 'PENDÊNCIA FINANCEIRA - Sua mensalidade do AliUai está pendente ou próxima do vencimento.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    isAtrasado ? 'Clique aqui para visualizar sua chave Pix e confirmar o pagamento.' : 'Clique aqui para efetuar o pagamento e manter seu estabelecimento ativo.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
