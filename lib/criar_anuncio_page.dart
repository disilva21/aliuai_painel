import 'package:aliuai_painel/pagamento_anuncio_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:aliuai/screens/pagamento_anuncio_page.dart';

class CriarAnuncioScreen extends StatefulWidget {
  const CriarAnuncioScreen({super.key});

  @override
  State<CriarAnuncioScreen> createState() => _CriarAnuncioScreenState();
}

class _CriarAnuncioScreenState extends State<CriarAnuncioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _precoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _whatsappController = TextEditingController();

  String _categoriaSelecionada = 'imoveis';
  bool _carregando = false;

  final List<Map<String, String>> _categorias = [
    {'id': 'imoveis', 'label': '🏡 Imóveis (Lotes, Chácaras, Casas)'},
    {'id': 'veiculos', 'label': '🚜 Veículos (Motos, Carros, Tratores)'},
    {'id': 'eletronicos', 'label': '📱 Celulares e Eletrônicos'},
    {'id': 'outros', 'label': '📦 Outros Produtos/Variados'},
  ];

  @override
  void initState() {
    super.initState();
    _puxarNomeUsuario();
  }

  void _puxarNomeUsuario() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _nomeController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _nomeController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _salvarAnuncioEIrParaPagamento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Uai! Você precisa estar logado para anunciar.');
      }

      // 1. Cria a referência do Anúncio antes para sabermos o ID dele sô!
      final docAnuncioRef = FirebaseFirestore.instance.collection('classificados').doc();
      final String idAnuncio = docAnuncioRef.id;

      final dadosAnuncio = {
        'anuncioId': idAnuncio,
        'usuarioUid': user.uid,
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'preco': double.tryParse(_precoController.text.replaceFirst(',', '.')) ?? 0.0,
        'categoria': _categoriaSelecionada,
        'fotos': [],
        'contato': {'nome': _nomeController.text.trim(), 'whatsapp': _whatsappController.text.trim().replaceAll(RegExp(r'[^\d]'), ''), 'cidadeId': 'pouso_alegre'},
        'criadoEm': FieldValue.serverTimestamp(),
        'status_pagamento': 'pendente',
        'ativo': false,
      };

      // 2. Grava o anúncio rascunho na coleção 'classificados'
      await docAnuncioRef.set(dadosAnuncio);

      // 3. Insere a semente do PIX de R$ 5,99 exatamente na mesma mecânica que você usa para as lojas!
      await FirebaseFirestore.instance.collection('pagamentos').add({
        'loja_id': user.uid, // O anunciante
        'referenciaId': idAnuncio, // ID do anúncio criado para o seu StreamBuilder ouvir
        'valor': 5.99,
        'nomeEstabelecimento': _nomeController.text.trim(),
        'tituloAnuncio': _tituloController.text.trim(),
        'status': 'pendente',
        'tipo': 'classificado', // 🔑 Muito importante! Diz pro seu webhook que é um anúncio comum
        'criadoEm': FieldValue.serverTimestamp(),
        'plano_pretendido': {'nome': 'Anuncio', 'limite_produtos': '0', 'limite_promocoes': '0'},
      });

      if (mounted) {
        // 4. Joga ele na tela do PIX apontando para o ID do anúncio
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PagamentoAnuncioScreen(anuncioId: idAnuncio)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar anúncio sô: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Anunciar no AliUai'), backgroundColor: const Color(0xFF00BDF2), foregroundColor: Colors.white, centerTitle: true),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BDF2)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BDF2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00BDF2).withOpacity(0.3)),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Anuncie seu lote, carro ou usado sô!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                          ),
                          SizedBox(height: 6),
                          Text('Valor fixo de R\$ 5,99 por 30 dias no ar.', style: TextStyle(fontSize: 13, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: _categoriaSelecionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category, color: Color(0xFF00BDF2)),
                      ),
                      items: _categorias.map((cat) {
                        return DropdownMenuItem<String>(value: cat['id'], child: Text(cat['label']!));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _categoriaSelecionada = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _tituloController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Título do Anúncio (Ex: Terreno 360m² Plano)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title, color: Color(0xFF00BDF2)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Insira um título sô!' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _precoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor Cobrado (R\$)',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.monetization_on, color: Color(0xFF00BDF2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Qual o preço do item sô?' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descricaoController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Detalhes do anúncio (Ex: documentação em dia, troca, etc)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60.0),
                          child: Icon(Icons.description, color: Color(0xFF00BDF2)),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Descreva o que está vendendo sô!' : null,
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Quem o comprador deve procurar?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),

                    TextFormField(
                      controller: _nomeController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Seu Nome',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: Color(0xFF00BDF2)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informa quem está vendendo!' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp com DDD (Ex: 35999998888)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_android, color: Color(0xFF00BDF2)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Deixe um telefone para contato sô!' : null,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _salvarAnuncioEIrParaPagamento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BDF2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Salvar e Ir para o PIX (R\$ 5,99)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
