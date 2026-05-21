import 'package:aliuai_painel/admin/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;

  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final emailDigitado = _emailController.text.trim();
    final senhaDigitada = _senhaController.text.trim();

    try {
      UserCredential? userCredential;

      try {
        // Tenta logar normalmente caso ele já tenha uma conta ativa no Auth
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);
      } on FirebaseAuthException catch (authError) {
        // PULO DO GATO: Se a conta não existe no Auth ou a senha está errada no Auth,
        // vamos verificar se há um pré-cadastro feito pelo Admin Master no Firestore
        if (authError.code == 'user-not-found' || authError.code == 'wrong-password' || authError.code == 'invalid-credential') {
          final queryPreCadastro = await FirebaseFirestore.instance
              .collection('usuarios')
              .where('email', isEqualTo: emailDigitado)
              .where('senha_provisoria', isEqualTo: senhaDigitada)
              .where('ativo', isEqualTo: true)
              .limit(1)
              .get();

          if (queryPreCadastro.docs.isNotEmpty) {
            // Encontrou o pré-cadastro! Vamos criar a credencial dele no Auth agora mesmo
            userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);

            final docId = queryPreCadastro.docs.first.id;

            // Vincula o UID do Auth ao documento do Firestore e limpa a senha provisória
            await FirebaseFirestore.instance.collection('usuarios').doc(docId).update({
              'uid': userCredential.user!.uid,
              'senha_provisoria': FieldValue.delete(), // Remove por segurança
            });
          } else {
            // Se não achou no Auth nem no pré-cadastro, lança o erro original
            throw authError;
          }
        } else {
          throw authError;
        }
      }

      // 3. Validação final de segurança do perfil carregado
      final verificarDoc = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: emailDigitado).limit(1).get();

      if (verificarDoc.docs.isNotEmpty) {
        final dados = verificarDoc.docs.first.data();

        // Garante que a conta não foi desativada e que ele pertence à equipe master
        if (dados['ativo'] == true && (dados['role'] == 'admin' || dados['role'] == 'vendedor')) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/admin/dashboard', (route) => false);
          }
        } else {
          await FirebaseAuth.instance.signOut();
          throw Exception('Esta conta foi desativada pela administração.');
        }
      } else {
        await FirebaseAuth.instance.signOut();
        throw Exception('Acesso restrito para equipe autorizada.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception:', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E26), // Fundo escuro imponente
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: Color(0xFF1E1E26),
                      height: 80,
                      child: Center(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            children: const [
                              TextSpan(
                                text: 'ali',
                                style: TextStyle(color: Colors.white), // Fica transparente sobre o fundo do app
                              ),
                              TextSpan(
                                text: 'uai',
                                style: TextStyle(color: Color(0xFFE65100)), // Seu Laranja Efí oficial!
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Administrador', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'E-mail Master', border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? 'Informe o e-mail' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha Restrita', border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? 'Informe a senha' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E26), foregroundColor: Colors.white),
                        onPressed: _carregando ? null : _loginAdmin,
                        child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Entrar no Sistema Master'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
