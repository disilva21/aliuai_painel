import 'package:aliuai_painel/cadastro_screen.dart';
import 'package:aliuai_painel/registro_anunciante_page.dart';
import 'package:flutter/material.dart';
// Importe suas telas de registro aqui sô!
// import 'package:aliuai/screens/registro_classificado_page.dart';
// import 'package:aliuai/screens/registro_estabelecimento_page.dart';

class EscolhaCadastroScreen extends StatelessWidget {
  const EscolhaCadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Criar Nova Conta'), backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Seja bem-vindo ao AliUai!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Para começarmos, selecione qual o seu objetivo principal no aplicativo sô:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.3),
              ),
              const SizedBox(height: 40),

              // 🏪 OPÇÃO 1: QUER CADASTRAR UM COMÉRCIO/SERVIÇO
              _buildCardOpcao(
                context,
                titulo: 'Sou Comerciante ou Profissional',
                descricao: 'Quero cadastrar minha loja, lanchonete, mercado, farmácia ou prestação de serviço para vender no app.',
                icone: Icons.storefront,
                corPrincipal: const Color(0xFFE65100), // Laranja Comercial
                onTap: () {
                  // TODO: Envia o usuário para a sua tela de registro de LOJAS
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroScreen()));
                },
              ),

              const SizedBox(height: 24),

              // 📢 OPÇÃO 2: QUER APENAS ANUNCIAR ITENS (CLASSIFICADOS)
              _buildCardOpcao(
                context,
                titulo: 'Quero Apenas Anunciar',
                subtituloExtra: 'R\$ 5,99 por anúncio',
                descricao: 'Quero criar uma conta rápida para vender itens específicos como terrenos, casas, carros, motos, celulares ou eletrônicos usados.',
                icone: Icons.campaign,
                corPrincipal: const Color(0xFF00BDF2), // Azul Celeste para os Classificados
                onTap: () {
                  // TODO: Envia o usuário para a sua nova tela de registro de ANUNCIANTES
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistroAnuncianteScreen()));
                },
              ),

              const Spacer(),

              // Link caso ele tenha clicado em cadastrar sem querer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Já tem uma conta?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Volta para a tela de login
                    },
                    child: const Text(
                      'Entrar',
                      style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Card Elegante
  Widget _buildCardOpcao(
    BuildContext context, {
    required String titulo,
    String? subtituloExtra,
    required String descricao,
    required IconData icone,
    required Color corPrincipal,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: corPrincipal.withOpacity(0.1),
          highlightColor: corPrincipal.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: corPrincipal.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icone, size: 32, color: corPrincipal),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corPrincipal),
                            ),
                          ),
                          if (subtituloExtra != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                subtituloExtra,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(descricao, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(top: 15.0, left: 8.0),
                    child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
