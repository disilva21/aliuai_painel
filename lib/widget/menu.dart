import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeusItensDeMenuWidget extends StatelessWidget {
  final int indexSelecionado;
  final Function(int) onUpdateIndex;
  final Widget Function({required int index, required String titulo, required IconData icone}) buildItemMenu;

  const MeusItensDeMenuWidget({super.key, required this.indexSelecionado, required this.onUpdateIndex, required this.buildItemMenu});

  @override
  Widget build(BuildContext context) {
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelular = larguraTela < 800;

    return Container(
      // 📐 Ocupa toda a largura que o pai (Drawer ou Row) der para ele sô!
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1E1E26),
      child: SingleChildScrollView(
        // Garante que em celulares pequenos o menu ganhe rolagem se faltar espaço
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'aliuai Admin',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // 🔘 Itens de Menu usando o seu construtor customizado
            buildItemMenu(index: 0, titulo: 'Dashboard', icone: Icons.delivery_dining_rounded),
            buildItemMenu(index: 1, titulo: 'Pedidos', icone: Icons.delivery_dining_rounded),
            buildItemMenu(index: 2, titulo: 'Produtos', icone: Icons.shopping_bag_outlined),
            buildItemMenu(index: 3, titulo: 'Promoções', icone: Icons.local_offer_outlined),
            buildItemMenu(index: 4, titulo: 'Eventos', icone: Icons.add_location_alt_outlined),
            buildItemMenu(index: 5, titulo: 'Meu Perfil', icone: Icons.storefront_outlined),
            buildItemMenu(index: 6, titulo: 'Planos de Assinatura', icone: Icons.rocket_launch_outlined),
            buildItemMenu(index: 7, titulo: 'Segurança', icone: Icons.lock_outline),

            const Divider(color: Colors.white10),

            // 🚪 Botão Sair da Conta
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  // Se estiver no celular, fecha o drawer antes de deslogar para evitar bugs visuais
                  if (ehCelular) Navigator.pop(context);

                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 24), // Espaço de segurança no rodapé
          ],
        ),
      ),
    );
  }
}
