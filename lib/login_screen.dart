import 'package:aliuai_painel/cadastro_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _carregando = false;
  bool _senhaInvisivel = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // Lógica de Autenticação no Firebase
  Future<void> _loginLojista() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final emailDigitado = _emailController.text.trim();
    final senhaDigitada = _senhaController.text.trim();

    try {
      UserCredential? userCredential;

      try {
        // 1. TENTA LOGAR NORMALMENTE (Caso a loja já tenha passado pelo primeiro acesso)
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);
      } on FirebaseAuthException catch (authError) {
        // 2. SE NÃO LOGAR, VERIFICA SE É O PRIMEIRO ACESSO DA LOJA CRIADA PELO ADMIN
        if (authError.code == 'user-not-found' || authError.code == 'wrong-password' || authError.code == 'invalid-credential') {
          // Procura na coleção 'estabelecimentos' se existe esse e-mail com essa senha provisória
          final queryPrimeiroAcesso = await FirebaseFirestore.instance
              .collection('estabelecimentos')
              .where('email', isEqualTo: emailDigitado)
              .where('senha_provisoria', isEqualTo: senhaDigitada)
              .where('ativo', isEqualTo: true)
              .limit(1)
              .get();

          if (queryPrimeiroAcesso.docs.isNotEmpty) {
            // O lojista bate com o cadastro do Admin! Criamos a conta oficial dele no Auth agora
            userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);

            final docId = queryPrimeiroAcesso.docs.first.id;

            // Vincula o UID gerado ao documento da loja e remove a senha provisória por segurança
            await FirebaseFirestore.instance.collection('estabelecimentos').doc(docId).update({
              'uid': userCredential.user!.uid, // Vincula para futuras consultas
              'senha_provisoria': FieldValue.delete(), // Deleta a senha em texto limpo do banco
            });
          } else {
            // Se não achou a senha provisória nem o usuário no Auth, joga o erro na tela
            throw FirebaseAuthException(code: 'acesso-invalido', message: 'E-mail ou senha incorretos, ou cadastro ainda não liberado pelo administrador.');
          }
        } else {
          throw authError;
        }
      }

      // 3. VALIDAÇÃO FINAL DE SEGURANÇA SE A LOJA ESTÁ ATIVA
      final docLoja = await FirebaseFirestore.instance.collection('estabelecimentos').where('email', isEqualTo: emailDigitado).limit(1).get();

      if (docLoja.docs.isNotEmpty) {
        final dados = docLoja.docs.first.data();

        if (dados['ativo'] == true) {
          if (mounted) {
            // Salva o ID da loja na sessão ou passa para a próxima tela
            final String lojaId = docLoja.docs.first.id;

            // Manda o lojista para o painel dele (Dashboard do Lojista)
            Navigator.pushReplacementNamed(
              context,
              '/home', // Ou a rota do home do seu lojista comum
              arguments: lojaId,
            );
          }
        } else {
          await FirebaseAuth.instance.signOut();
          throw Exception('Este estabelecimento está desativado no sistema.');
        }
      } else {
        await FirebaseAuth.instance.signOut();
        throw Exception('Dados do estabelecimento não encontrados.');
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
    // Captura a largura da tela para saber se é computador ou celular
    final larguraTela = MediaQuery.of(context).size.width;
    final IsDesktop = larguraTela > 600;

    return Scaffold(
      body: Center(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            // Mapeia a tecla Enter (tanto do teclado normal quanto do numérico)
            const SingleActivator(LogicalKeyboardKey.enter): () {
              _loginLojista(); // Sua função que o botão "Entrar" já chama
            },
          },
          child: Focus(
            autofocus: true,
            child: SingleChildScrollView(
              child: Container(
                width: IsDesktop ? 450 : larguraTela * 0.9, // Limita o tamanho no PC
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo / Identidade do Painel
                      // Container(height: 120, color: Color(0xFF1E1E26), child: Image.asset('assets/logo/logo_aliuai.png')),
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
                      // const Icon(Icons.storefront, size: 64, color: Color(0xFFE65100)),
                      const SizedBox(height: 12),
                      const Text(
                        'Painel',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gerencie seus produtos e vendas em tempo real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),

                      // CAMPO DE E-MAIL
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-mail de Acesso',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.isEmpty || !valor.contains('@')) {
                            return 'Informe um e-mail válido, sô!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // CAMPO DE SENHA
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _senhaInvisivel,
                        onFieldSubmitted: (valor) {
                          // _fazerLogin(); // Troque pelo nome da sua função de login
                        },
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE65100)),
                          suffixIcon: IconButton(icon: Icon(_senhaInvisivel ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _senhaInvisivel = !_senhaInvisivel)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().length < 6) {
                            return 'A senha deve ter pelo menos 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // BOTÃO DE LOGIN
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _carregando ? null : _loginLojista,
                          child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Entrar no Painel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sua empresa não está no aliuai?'),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CadastroScreen()));
                            },
                            child: const Text(
                              'Cadastre-se aqui',
                              style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
