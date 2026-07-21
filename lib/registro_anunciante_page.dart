import 'package:aliuai_painel/criar_anuncio_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class RegistroAnuncianteScreen extends StatefulWidget {
  const RegistroAnuncianteScreen({super.key});

  @override
  State<RegistroAnuncianteScreen> createState() => _RegistroAnuncianteScreenState();
}

class _RegistroAnuncianteScreenState extends State<RegistroAnuncianteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _whatsappController = TextEditingController();

  bool _senhaVisivel = false;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  // 🔥 Função que cria a conta no Firebase Auth e inicia o usuário no Firestore
  Future<void> _criarContaAnunciante() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      // 1. Cria o login no Firebase Authentication
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _senhaController.text.trim());

      final User? user = userCredential.user;

      if (user != null) {
        // Atualiza o nome de exibição no Auth nativo do Firebase
        await user.updateDisplayName(_nomeController.text.trim());

        // 2. Cria o documento dele na coleção de 'usuarios' no Firestore
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'uid': user.uid,
          'nome': _nomeController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'anunciante', // 📢 Define que ele é um perfil de Classificados!
          'criadoEm': FieldValue.serverTimestamp(),
          'telefone': '', // Usuário pode preencher no perfil depois uai
          'ativo': true, // Usuário está ativo por padrão
          'plataforma': 'painel',
        });

        if (mounted) {
          // 3. Limpa as telas antigas e joga ele direto no formulário de Anúncio!
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CriarAnuncioScreen()),
            (Route<dynamic> route) => false, // Remove todo o histórico de login do caminho
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Ocorreu um erro ao criar sua conta sô.';

      if (e.code == 'weak-password') {
        mensagemErro = 'Essa senha está muito fraca, sô! Escolha uma mais forte.';
      } else if (e.code == 'email-already-in-use') {
        mensagemErro = 'Uai, esse e-mail já está cadastrado em outra conta!';
      } else if (e.code == 'invalid-email') {
        mensagemErro = 'Esse formato de e-mail não parece certo.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cadastro de Anunciante'),
        backgroundColor: const Color(0xFF00BDF2), // Usando o azul dos Classificados
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BDF2)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1, size: 64, color: Color(0xFF00BDF2)),
                    const SizedBox(height: 16),
                    const Text(
                      'Crie sua conta rapidinho!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Com ela você poderá gerenciar e destacar seus anúncios de forma muito fácil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // Nome Completo
                    TextFormField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nome Completo', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Insira seu nome sô!' : null,
                    ),
                    const SizedBox(height: 16),

                    // E-mail
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Seu E-mail', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informa o e-mail uai!';
                        if (!v.contains('@') || !v.contains('.')) return 'E-mail inválido sô!';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // E-mail
                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp (com DDD)',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        counterText: '',
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          // 1. Remove tudo o que não for número sô
                          String texto = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

                          // Se o lojista estiver apagando, deixa o homem trabalhar em paz sô
                          if (newValue.text.length < oldValue.text.length) {
                            return newValue;
                          }

                          String textoFormatado = "";

                          // 2. Monta a máscara certinha sem espaços duplicados sô!
                          if (texto.length > 0) {
                            textoFormatado += "(${texto.substring(0, texto.length.clamp(0, 2))}";
                          }
                          if (texto.length > 2) {
                            // Juntamos o fecha parêntese com o espaço padrão sô: ") "
                            textoFormatado += ") ${texto.substring(2, texto.length.clamp(2, 7))}";
                          }
                          if (texto.length > 7) {
                            // Corta os primeiros 5 dígitos do número e mete o hífen pro restante sô
                            textoFormatado = "(${texto.substring(0, 2)}) ${texto.substring(2, 7)}-${texto.substring(7, texto.length.clamp(7, 11))}";
                          }

                          return TextEditingValue(
                            text: textoFormatado,
                            selection: TextSelection.collapsed(offset: textoFormatado.length),
                          );
                        }),
                      ],
                      validator: (val) => val!.isEmpty ? 'O WhatsApp é obrigatório.' : null,
                    ),
                    const SizedBox(height: 16),
                    // Senha
                    TextFormField(
                      controller: _senhaController,
                      obscureText: !_senhaVisivel,
                      decoration: InputDecoration(
                        labelText: 'Criar Senha',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel)),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'A senha precisa ter no mínimo 6 dígitos!' : null,
                    ),
                    const SizedBox(height: 16),

                    // Confirmar Senha
                    TextFormField(
                      controller: _confirmarSenhaController,
                      obscureText: !_senhaVisivel,
                      decoration: const InputDecoration(labelText: 'Confirmar Senha', prefixIcon: Icon(Icons.lock_clock), border: OutlineInputBorder()),
                      validator: (v) {
                        if (v != _senhaController.text) return 'As senhas não combinam sô!';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Botão Finalizar
                    ElevatedButton(
                      onPressed: _criarContaAnunciante,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BDF2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Criar Conta e Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
