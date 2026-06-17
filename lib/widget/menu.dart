import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF1E1E26), // 🖤 Seu fundo escuro chique sô!
      child: Column(
        children: [
          // 📦 1. CONTEÚDO ROLÁVEL (Os itens do menu rolam se a tela for pequena sô!)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
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
                  buildItemMenu(index: 7, titulo: 'Cardeneta Fiado', icone: Icons.menu_book_rounded),
                  buildItemMenu(index: 8, titulo: 'Segurança', icone: Icons.lock_outline),
                ],
              ),
            ),
          ),

          // 🔒 2. RODAPÉ FIXO (Fica preso embaixo da tela e nunca some sô!)
          const Divider(color: Colors.white10, height: 1),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                if (ehCelular) Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final info = snapshot.data!;
                  return Text(
                    'Versão v${info.version}-${info.buildNumber}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500), // Cor visível sô!
                  );
                }

                // 🔥 AJUSTADO: Texto de segurança agora está claro (white38) para não sumir no fundo escuro sô!
                return const Text(
                  'Versão v1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
