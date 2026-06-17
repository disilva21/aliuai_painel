import 'package:flutter/material.dart';

class TermosUsoPage extends StatelessWidget {
  const TermosUsoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso - Aliuai 🤠'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Container(
        color: Colors.grey[50],
        child: Center(
          child: Container(
            width: 800, // Limita a largura para ficar chique no monitor sô!
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERMOS AND CONDIÇÕES GERAIS DE USO',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Última atualização: Junho de 2026',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  Divider(height: 32),

                  Text('1. DO OBJETO DA PLATAFORMA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O Aliuai é uma plataforma tecnológica de gerenciamento e intermediação que oferece ferramentas para que lojistas/parceiros gerenciem seus negócios, pedidos e integrações. A plataforma atua puramente como fornecedora de software (SaaS), não integrando a cadeia de consumo direta dos produtos vendidos pelo Lojista.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('2. CADASTRO E SEGURANÇA DA CONTA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O Lojista é o único responsável pela veracidade e atualização de seus dados cadastrais. O acesso à Dashboard é pessoal e intransferível. O Lojista compromete-se a manter em sigilo suas senhas de acesso, eximindo o Aliuai de qualquer responsabilidade por acessos indevidos.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('3. DO CANAL DE SUPORTE E CHAT INTERNO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O uso do chat de suporte destina-se exclusivamente à resolução de dúvidas técnicas, operacionais e financeiras ligadas à plataforma. É expressamente proibido o uso de linguagem ofensiva, injuriosa, caluniosa ou de cunho discriminatório contra os operadores de suporte do Aliuai. O descumprimento poderá resultar na suspensão temporária ou bloqueio definitivo do acesso.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('4. LIMITAÇÃO DE RESPONSABILIDADE JURÍDICA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O Aliuai não possui qualquer responsabilidade civil, trabalhista, fiscal ou consumerista pelas transações comerciais realizadas entre o Lojista e seus clientes finais. O Lojista assume total responsabilidade pelos produtos vendidos, entregas, trocas e garantias. O Aliuai não se responsabiliza por lucros cessantes decorrentes de manutenções necessárias ou instabilidades na rede.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('5. PRIVACIDADE E PROTEÇÃO DE DADOS (LGPD)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O Aliuai coleta e processa dados estritamente necessários para o funcionamento do ecossistema, em total conformidade com a Lei Geral de Proteção de Dados (Lei nº 13.709/2018). As conversas do chat de suporte são armazenadas com o único propósito de auditoria, histórico de atendimento e melhoria do serviço.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('6. PROPRIEDADE INTELECTUAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'Todo o código-fonte, layout da Dashboard, marcas, logotipos e identidades visuais da plataforma pertencem exclusivamente ao Aliuai. O Lojista possui apenas uma licença de uso temporária e revogável.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('7. MODIFICAÇÕES NOS TERMOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'O Aliuai reserva-se o direito de alterar estes Termos de Uso a qualquer momento. As alterações serão notificadas na Dashboard do Lojista e o uso continuado implicará na aceitação das novas regras.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),

                  Text('8. FORO DE ELEIÇÃO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'Para dirimir quaisquer controvérsias oriundas do presente Termo, as partes elegem o Foro da Comarca de São Paulo/SP, com renúncia expressa a qualquer outro.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
