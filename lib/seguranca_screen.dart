import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SegurancaScreen extends StatefulWidget {
  const SegurancaScreen({super.key});

  @override
  State<SegurancaScreen> createState() => _SegurancaScreenState();
}

class _SegurancaScreenState extends State<SegurancaScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  final _formEmailKey = GlobalKey<FormState>();
  final _formSenhaKey = GlobalKey<FormState>();

  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    // Já puxa o e-mail logado atualmente para mostrar no campo
    _emailController.text = _auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  // MÉTODO PARA ATUALIZAR O E-MAIL (No Auth e no Firestore)
  Future<void> _atualizarEmail() async {
    if (!_formEmailKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      final usuario = _auth.currentUser;
      final novoEmail = _emailController.text.trim();

      if (usuario != null) {
        // 🔥 O PULO DO GATO: Troque updateEmail por verifyBeforeUpdateEmail
        await usuario.verifyBeforeUpdateEmail(novoEmail);

        // Atualiza também no documento do estabelecimento no Firestore
        await _firestore.collection('estabelecimentos').doc(usuario.uid).update({'email': novoEmail});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link de confirmação enviado para o novo e-mail! ✉️'), backgroundColor: Colors.orange));
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Erro ao atualizar e-mail.';
      if (e.code == 'requires-recent-login') {
        mensaje = 'Por segurança, faça logout e login novamente antes de mudar o e-mail.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // MÉTODO PARA ALTERAR A SENHA
  Future<void> _atualizarSenha() async {
    if (!_formSenhaKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      final usuario = _auth.currentUser;

      if (usuario != null) {
        // O Firebase exige que o usuário tenha logado recentemente para mudar a senha.
        await usuario.updatePassword(_novaSenhaController.text.trim());

        _senhaAtualController.clear();
        _novaSenhaController.clear();
        _confirmarSenhaController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso! 🔒'), backgroundColor: Colors.green));
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao atualizar senha.';
      if (e.code == 'requires-recent-login') {
        mensagem = 'Ação sensível! Por segurança, saia e entre novamente no painel para alterar a senha.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🖥️ Verifica a largura para saber se renderiza em modo celular
    final bool ehCelular = MediaQuery.of(context).size.width < 800;

    // 📦 Bloco 1: Formulário de E-mail isolado para reaproveitamento
    final Widget cardEmail = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formEmailKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('E-mail de Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                enabled: false, // Atualmente travado conforme seu padrão original sô!
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail de Acesso',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) => val!.isEmpty ? 'Digite um e-mail válido.' : null,
              ),
              const SizedBox(height: 24),
              // Descomente abaixo caso queira reativar o botão de salvar e-mail futuramente
              // SizedBox(
              //   width: ehCelular ? double.infinity : null,
              //   child: ElevatedButton(
              //     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              //     onPressed: _carregando ? null : _atualizarEmail,
              //     child: _carregando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar Novo E-mail'),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );

    // 📦 Bloco 2: Formulário de Senha isolado
    final Widget cardSenha = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formSenhaKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alterar Senha de Acesso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _novaSenhaController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nova Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) => val!.length < 6 ? 'A senha deve ter no mínimo 6 caracteres.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmarSenhaController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar Nova Senha',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val != _novaSenhaController.text) {
                    return 'As senhas não coincidem, sô!';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                // Botão expande no celular para ficar confortável de tocar
                width: ehCelular ? double.infinity : null,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: ehCelular ? const EdgeInsets.symmetric(vertical: 16) : null),
                  onPressed: _carregando ? null : _atualizarSenha,
                  child: _carregando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Modificar Senha'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Padding(
          // Reduz o padding geral no celular para as caixas aproveitarem as bordas físicas da tela
          padding: EdgeInsets.all(ehCelular ? 16.0 : 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🔑 Dados de Acesso & Segurança',
                style: TextStyle(fontSize: ehCelular ? 22 : 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              const Text('Gerencie o e-mail de login e a senha de segurança do seu painel administrativo.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 32),

              // 🔀 A MÁGICA DA RESPONSIVIDADE:
              // Se for celular, renderiza uma Column (empilhado). Se for PC, renderiza uma Row (lado a lado).
              if (ehCelular)
                Column(children: [cardEmail, const SizedBox(height: 16), cardSenha])
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardEmail),
                    const SizedBox(width: 24),
                    Expanded(child: cardSenha),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
