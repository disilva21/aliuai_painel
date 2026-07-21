import 'package:aliuai_painel/criar_anuncio_page.dart';
import 'package:aliuai_painel/escolha_cadastro_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Importe suas telas reais aqui sô!
// import 'package:aliuai/screens/criar_anuncio_page.dart';
// import 'package:aliuai/screens/escolha_cadastro_page.dart';

class PainelControllerScreen extends StatefulWidget {
  const PainelControllerScreen({super.key});

  @override
  State<PainelControllerScreen> createState() => _PainelControllerScreenState();
}

class _PainelControllerScreenState extends State<PainelControllerScreen> {
  final String _userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    if (_userUid.isEmpty) {
      // Se por algum motivo o UID estiver vazio, joga para o login de segurança
      return const Scaffold(body: Center(child: Text('Uai! Usuário não autenticado.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: StreamBuilder<DocumentSnapshot>(
        // 🔍 Escuta em tempo real o perfil do usuário logado na coleção 'usuarios'
        stream: FirebaseFirestore.instance.collection('usuarios').doc(_userUid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(child: Text('Erro ao carregar seu perfil sô.'));
          }

          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            // Se o documento do usuário não existir na coleção 'usuarios',
            // joga ele na tela de escolha para ele se cadastrar corretamente.
            return const EscolhaCadastroScreen();
          }

          // Pega os dados do perfil do usuário
          final dadosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
          final String role = dadosUsuario['role'] ?? 'anunciante';

          return StreamBuilder<QuerySnapshot>(
            // 🔍 Verifica se existe algum estabelecimento vinculado a este UID
            stream: FirebaseFirestore.instance.collection('estabelecimentos').where('donoUid', isEqualTo: _userUid).limit(1).snapshots(),
            builder: (context, estabSnapshot) {
              if (estabSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
              }

              final bool temEstabelecimento = estabSnapshot.hasData && estabSnapshot.data!.docs.isNotEmpty;

              // 🏪 CASO 1: É Lojista (ou já possui estabelecimento cadastrado)
              if (role == 'lojista' || temEstabelecimento) {
                final dadosLoja = temEstabelecimento ? estabSnapshot.data!.docs.first.data() as Map<String, dynamic> : null;

                return _buildPainelLojista(dadosUsuario, dadosLoja);
              }

              // 📢 CASO 2: É Anunciante puro (não possui estabelecimento)
              return _buildPainelAnunciante(dadosUsuario);
            },
          );
        },
      ),
    );
  }

  // 🏪 PAINEL DO LOJISTA
  Widget _buildPainelLojista(Map<String, dynamic> usuario, Map<String, dynamic>? loja) {
    final String nomeLoja = loja != null ? (loja['nomeComercial'] ?? 'Minha Loja') : 'Cadastrando Loja...';

    return Scaffold(
      appBar: AppBar(
        title: Text(nomeLoja),
        backgroundColor: const Color(0xFFE65100), // Laranja Comercial
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Color(0xFFE65100)),
              const SizedBox(height: 16),
              Text(
                'Bem-vindo ao Painel da sua Loja, sô!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Olá, ${usuario['nome']}! Aqui você gerencia seus produtos e pedidos.'),
              const SizedBox(height: 32),

              // Botões de gerenciamento da loja (sua fiação original)
              ElevatedButton.icon(
                onPressed: () {
                  // Abre gerenciador de produtos
                },
                icon: Icon(Icons.gif_box),
                label: const Text('Meus Produtos'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              ),
              const SizedBox(height: 12),

              // 💡 Olha o Cross-selling aqui sô! O lojista também pode anunciar nos classificados!
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CriarAnuncioScreen()));
                },
                icon: const Icon(Icons.campaign, color: Color(0xFF00BDF2)),
                label: const Text('Quero criar um Anúncio Classificado (R\$ 5,99)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📢 PAINEL DO ANUNCIANTE (CLASSIFICADOS)
  Widget _buildPainelAnunciante(Map<String, dynamic> usuario) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Anúncios'),
        backgroundColor: const Color(0xFF00BDF2), // Azul Classificados
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho de Boas-vindas
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00BDF2).withOpacity(0.2),
                  child: const Icon(Icons.person, color: Color(0xFF00BDF2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá, ${usuario['nome']} sô!', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Perfil Anunciante', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Card Informativo / Chamada para Criar Anúncio
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00BDF2).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.campaign, size: 48, color: Color(0xFF00BDF2)),
                  const SizedBox(height: 12),
                  const Text('Venda rápido no AliUai!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Anuncie terrenos, carros, eletrônicos ou usados por apenas R\$ 5,99 sô!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CriarAnuncioScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BDF2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Criar Novo Anúncio'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('Seus Anúncios Cadastrados:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 🔍 Busca apenas os classificados que pertencem a este anunciante
                stream: FirebaseFirestore.instance.collection('classificados').where('usuarioUid', isEqualTo: _userUid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Erro ao carregar seus anúncios sô.'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF00BDF2)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Você ainda não tem nenhum anúncio cadastrado sô!',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final anuncio = doc.data() as Map<String, dynamic>;

                      final String titulo = anuncio['titulo'] ?? 'Sem título';
                      final double preco = anuncio['preco'] ?? 0.0;
                      final String statusPg = anuncio['statusPagamento'] ?? 'pendente';
                      final bool ativo = anuncio['ativo'] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.shopping_bag, color: Color(0xFF00BDF2)),
                          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('R\$ ${preco.toStringAsFixed(2)}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: ativo ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              ativo ? 'No Ar' : (statusPg == 'pendente' ? 'Aguardando PIX' : 'Inativo'),
                              style: TextStyle(color: ativo ? Colors.green[800] : Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
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
