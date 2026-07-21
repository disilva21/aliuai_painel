import 'package:aliuai_painel/cadastro_screen.dart';
import 'package:aliuai_painel/escolha_cadastro_screen.dart';
import 'package:aliuai_painel/painel_controller_screen.dart';

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

  Future<void> _loginLojista() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    final emailDigitado = _emailController.text.trim();
    final senhaDigitada = _senhaController.text.trim();

    try {
      UserCredential? userCredential;

      try {
        // 1. TENTA LOGAR NORMALMENTE (Caso a loja, funcionário ou anunciante já tenham passado pelo primeiro acesso)
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);
      } on FirebaseAuthException catch (authError) {
        // 2. SE NÃO LOGAR, VERIFICA SE É O PRIMEIRO ACESSO (DA LOJA OU DO FUNCIONÁRIO)
        if (authError.code == 'user-not-found' || authError.code == 'wrong-password' || authError.code == 'invalid-credential') {
          // 2.1 Tenta achar primeiro na coleção 'estabelecimentos' (Primeiro acesso do Lojista)
          final queryPrimeiroAcessoLoja = await FirebaseFirestore.instance
              .collection('estabelecimentos')
              .where('email', isEqualTo: emailDigitado)
              .where('senha_provisoria', isEqualTo: senhaDigitada)
              .where('ativo', isEqualTo: true)
              .limit(1)
              .get();

          if (queryPrimeiroAcessoLoja.docs.isNotEmpty) {
            // O lojista bate com o cadastro do Admin! Criamos a conta oficial dele no Auth agora
            userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);

            final docId = queryPrimeiroAcessoLoja.docs.first.id;

            // Vincula o UID gerado ao documento da loja e remove a senha provisória por segurança
            await FirebaseFirestore.instance.collection('estabelecimentos').doc(docId).update({
              'uid': userCredential.user!.uid, // Vincula para futuras consultas
              'senha_provisoria': FieldValue.delete(), // Deleta a senha em texto limpo do banco
            });
          } else {
            // 2.2 Se não achou na loja, tenta na coleção 'funcionarios' (Primeiro acesso do Funcionário)
            final queryPrimeiroAcessoFunc = await FirebaseFirestore.instance
                .collection('funcionarios')
                .where('email', isEqualTo: emailDigitado)
                .where('senha_padrao', isEqualTo: senhaDigitada)
                .where('ativo', isEqualTo: true)
                .limit(1)
                .get();

            if (queryPrimeiroAcessoFunc.docs.isNotEmpty) {
              // O funcionário bate com o cadastro feito pelo lojista! Criamos a conta oficial dele no Auth agora
              userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailDigitado, password: senhaDigitada);

              final docIdFunc = queryPrimeiroAcessoFunc.docs.first.id;

              // Atualiza o documento do funcionário com o UID e remove a senha padrão provisória
              await FirebaseFirestore.instance.collection('funcionarios').doc(docIdFunc).update({
                'uid': userCredential.user!.uid,
                'senha_padrao': FieldValue.delete(),
                'precisa_trocar_senha': true, // Mantém a regra para exigir troca na primeira entrada se desejar
              });
            } else {
              // Se não achou a senha em nenhuma das coleções nem o usuário no Auth, joga o erro na tela
              throw FirebaseAuthException(code: 'acesso-invalido', message: 'E-mail ou senha incorretos, ou cadastro ainda não liberado.');
            }
          }
        } else {
          throw authError;
        }
      }

      // 3. VALIDAÇÃO FINAL DE SEGURANÇA (Se é Usuário Geral, Dono Tradicional ou Funcionário)
      final userUid = FirebaseAuth.instance.currentUser!.uid;

      // 🔑 3.1 NOVA FIÇÃO: Verifica se o login pertence à coleção global 'usuarios'
      // (Isso abrange os Anunciantes e os Lojistas modernos)
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(userUid).get();

      if (docUsuario.exists) {
        final dadosUsuario = docUsuario.data()!;
        final String role = dadosUsuario['role'] ?? 'anunciante';
        final bool ativo = dadosUsuario['ativo'] ?? true;

        if (ativo) {
          if (mounted) {
            // 🚀 Manda direto para o Roteador Inteligente que sabe renderizar
            // a tela certa para o Anunciante ou para o Lojista sô!
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PainelControllerScreen()));
          }
          return; // Finaliza o método com sucesso sô!
        } else {
          await FirebaseAuth.instance.signOut();
          throw Exception('Esta conta de usuário está desativada no sistema sô.');
        }
      }

      // 3.2 FLUXO LEGADO: Tenta encontrar na coleção 'estabelecimentos' (Dono Legado)
      final docLoja = await FirebaseFirestore.instance.collection('estabelecimentos').where('uid', isEqualTo: userUid).limit(1).get();

      if (docLoja.docs.isNotEmpty) {
        final dados = docLoja.docs.first.data();

        if (dados['ativo'] == true) {
          if (mounted) {
            final String lojaId = docLoja.docs.first.id;
            Navigator.pushReplacementNamed(context, '/home', arguments: lojaId);
          }
          return;
        } else {
          await FirebaseAuth.instance.signOut();
          throw Exception('Este estabelecimento está desativado no sistema.');
        }
      }

      // 3.3 FLUXO LEGADO: Se não for dono, valida se é funcionário na coleção 'funcionarios'
      final docFuncionario = await FirebaseFirestore.instance.collection('funcionarios').doc(userUid).get();

      if (docFuncionario.exists) {
        final dadosFunc = docFuncionario.data()!;

        if (dadosFunc['ativo'] == true) {
          if (mounted) {
            final String lojaId = dadosFunc['estabelecimento_id'];
            // Redireciona para a home do funcionário (ou a mesma home passando a loja e flag)
            Navigator.pushReplacementNamed(context, '/home', arguments: lojaId);
          }
          return;
        } else {
          await FirebaseAuth.instance.signOut();
          throw Exception('Este acesso de funcionário está desativado.');
        }
      }

      // Se passou pelo Auth mas não está em nenhuma das coleções do Firestore
      await FirebaseAuth.instance.signOut();
      throw Exception('Dados do usuário não encontrados no sistema.');
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
                      Align(
                        alignment: Alignment.centerRight, // Alinha na direita pra ficar chique sô
                        child: TextButton(
                          onPressed: () {
                            // Pega o e-mail que o lojista já digitou no campo de login e dispara
                            _modalEsqueciSenha(context);
                          },
                          child: const Text(
                            'Primeiro Acesso / Recuperar Senha? 🤠',
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.amber[50],
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Sua empresa não está no aliuai?',
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EscolhaCadastroScreen()));
                                },
                                child: const Text(
                                  'Cadastre-se aqui',
                                  style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  void _modalEsqueciSenha(BuildContext context) {
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Puxador central
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            const Icon(Icons.lock_reset_rounded, size: 48, color: Color(0xFFE65100)),
            const SizedBox(height: 16),

            const Text('Criar/Recuperar acesso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Digite seu e-mail cadastrado e enviaremos as instruções para definir uma nova senha.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () async {
                  if (emailController.text.isNotEmpty) {
                    // Ação de enviar o e-mail
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Instruções enviadas para seu e-mail, verifique lá! 📧')));
                    }
                  }
                },
                child: const Text(
                  'Enviar instruções',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
