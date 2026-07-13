import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EquipeScreen extends StatefulWidget {
  final String lojaId; // Precisamos saber de qual loja estamos falando sô!
  const EquipeScreen({super.key, required this.lojaId});

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final double larguraTela = MediaQuery.of(context).size.width;
    final bool ehCelularGeral = larguraTela < 800;

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho Responsivo (Mesmo padrão do Produtos)
          LayoutBuilder(
            builder: (context, constraints) {
              final bool ehCelularTop = constraints.maxWidth < 800;

              final Widget blocoTextos = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👥 Equipe da Loja',
                    style: TextStyle(fontSize: ehCelularTop ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text('Gerencie seus funcionários e níveis de acesso sô.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              );

              final Widget botaoNovo = SizedBox(
                width: ehCelularTop ? double.infinity : null,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.person_add, size: 20),
                  label: const Text('Novo Funcionário', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _modalNovoFuncionario,
                ),
              );

              return ehCelularTop
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [blocoTextos, const SizedBox(height: 16), botaoNovo])
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: blocoTextos),
                        botaoNovo,
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),

          // 2. Lista de Equipe (Com o mesmo Card limpo do Produtos)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('funcionarios').where('estabelecimento_id', isEqualTo: widget.lojaId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum funcionário cadastrado sô! 🌾'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final dados = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(dados['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${dados['email']} • Cargo: ${dados['nivel_acesso']?.toUpperCase()}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deletarFuncionario(docs[index].id),
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
    );
  }

  String gerarSenhaProvisoriaFuncionario() {
    final random = Random();
    // Gera um número aleatório entre 1000 e 9999
    final numeroAleatorio = 1000 + random.nextInt(9000);
    return 'aliuai$numeroAleatorio';
  }

  void _modalNovoFuncionario() {
    final nomeController = TextEditingController();
    final emailController = TextEditingController();
    String nivel = 'operador';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Necessário para o modal subir quando o teclado abrir
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Ajuste para o teclado não tapar o campo
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de puxar (o "puxador" visual)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Adicionar Colaborador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Preencha os dados para convidar um novo membro.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome do Funcionário', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField(
              value: nivel,
              decoration: const InputDecoration(labelText: 'Cargo / Nível de Acesso', border: OutlineInputBorder()),
              items: ['operador', 'estoquista', 'gerente'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
              onChanged: (val) => nivel = val.toString(),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () async {
                  try {
                    // 1. Criar o usuário no Auth para ele conseguir logar
                    UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: emailController.text.trim(),
                      password: 'aliuaiMudar', //gerarSenhaProvisoriaFuncionario(), // Senha padrão sô!
                    );

                    // 2. Salvar no Firestore com a flag de "troca obrigatória"
                    await _firestore.collection('funcionarios').doc(cred.user!.uid).set({
                      'nome': nomeController.text,
                      'email': emailController.text.trim(),
                      'estabelecimento_id': widget.lojaId,
                      'nivel_acesso': nivel,
                      'ativo': true,
                      'precisa_trocar_senha': true, // 🔒 Flag que trava o trator
                      'criado_em': FieldValue.serverTimestamp(),
                    });

                    // 2. Avisa o dono que deu certo
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funcionário cadastrado! Ele já pode fazer o primeiro acesso no Painel!')));
                    }
                  } catch (e) {
                    print("Erro ao cadastrar: $e");
                    // Mostra erro pro dono
                  }
                },
                child: const Text(
                  'Cadastrar Funcionário',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _deletarFuncionario(String id) => _firestore.collection('funcionarios').doc(id).delete();
}
