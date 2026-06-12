import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 🔥 Precisa rodar 'flutter pub add http' sô!

class CadastroProdutoScreen extends StatefulWidget {
  final String lojaId;
  const CadastroProdutoScreen({super.key, required this.lojaId});

  @override
  State<CadastroProdutoScreen> createState() => _CadastroProdutoScreenState();
}

class _CadastroProdutoScreenState extends State<CadastroProdutoScreen> {
  // 🎮 Controladores dos campos sô
  final TextEditingController _barrasController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();

  final FocusNode _barrasFocusNode = FocusNode();
  final FocusNode _nomeFocusNode = FocusNode();

  bool _buscandoCodigo = false;

  @override
  void initState() {
    super.initState();
    // 🎯 Assim que a tela abre, já joga o foco no campo do código de barras.
    // O feirante só precisa pegar a pistola e bipar, sem nem tocar no mouse sô!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barrasFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barrasController.dispose();
    _nomeController.dispose();
    _precoController.dispose();
    _descricaoController.dispose();
    _barrasFocusNode.dispose();
    _nomeFocusNode.dispose();
    super.dispose();
  }

  // 📡 INTEGRAÇÃO COM A API DE CÓDIGO DE BARRAS SÔ (CORRIGIDO!)
  Future<void> _buscarProdutoPeloCodigo(String codigo) async {
    if (codigo.trim().isEmpty) return;

    setState(() => _buscandoCodigo = true);

    try {
      // 🎯 Usando a API pública da Cosmos/BrasilAPI ou similar para buscar o produto sô
      // final url = Uri.parse('https://brasilapi.com.br/api/isbn/v1/${codigo.trim()}');
      // final resposta = await http.get(url);

      // URL para buscar qualquer produto de supermercado do mundo sô!
      final url = Uri.parse('https://br.openfoodfacts.org/api/v2/product/${codigo.trim()}.json');
      final resposta = await http.get(url);

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        if (dados['status'] == 1) {
          // 1 significa que achou o produto!
          final produto = dados['product'];
          setState(() {
            _nomeController.text = produto['product_name'] ?? '';
            _descricaoController.text = produto['generic_name'] ?? '';
          });
        }
      }
      // if (resposta.statusCode == 200) {
      //   final dados = jsonDecode(resposta.body);
      //   setState(() {
      //     // Preenche os campos automáticos sô
      //     _nomeController.text = dados['title'] ?? dados['nome'] ?? '';
      //     _descricaoController.text = dados['authors']?.join(', ') ?? dados['descricao'] ?? '';
      //   });
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produto localizado com sucesso! 🏷️'), backgroundColor: Colors.green));
      //   }
      // }
      else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código bipado, mas não achado na nuvem. Pode digitar o nome sô!'), backgroundColor: Colors.orange));
        }
        _nomeFocusNode.requestFocus(); // Joga o foco pro nome pro lojista digitar sô
      }
    } catch (e) {
      print('Erro ao buscar código sô: $e');
    } finally {
      if (mounted) {
        setState(() => _buscandoCodigo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Produto com Leitor 🏷️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulário de Cadastro sô
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1️⃣ CAMPO DO CÓDIGO DE BARRAS (O ALVO DA PISTOLA!)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barrasController,
                          focusNode: _barrasFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Bipe o Código de Barras do Produto',
                            hintText: 'Pode passar o leitor de pistola aqui sô...',
                            prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                            border: const OutlineInputBorder(),
                            suffixIcon: _buscandoCodigo
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE65100)),
                                    ),
                                  )
                                : IconButton(icon: const Icon(Icons.clear), onPressed: () => _barrasController.clear()),
                          ),
                          // 🎯 O PULO DO GATO: O leitor bipe, digita os números e dá "Enter".
                          // O onSubmitted captura o "Enter" automático do leitor sô!
                          onSubmitted: (valorBipado) {
                            _buscarProdutoPeloCodigo(valorBipado);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2️⃣ CAMPO DO NOME DO PRODUTO
                  TextField(
                    controller: _nomeController,
                    focusNode: _nomeFocusNode,
                    decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),

                  // 3️⃣ ROW DE PREÇO E CATEGORIA
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _precoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Preço de Venda (R\$)', border: OutlineInputBorder(), prefixText: 'R\$ '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4️⃣ DESCRIÇÃO DO PRODUTO
                  TextField(
                    controller: _descricaoController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Descrição ou Detalhes', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 32),

                  // BOTÃO SALVAR PRODUTO SÔ
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                      onPressed: () {
                        // Aqui você roda o seu FirebaseFirestore para salvar o produto normal sô!
                        print('Salvando: ${_nomeController.text} com o EAN: ${_barrasController.text}');
                      },
                      child: const Text(
                        'Salvar Produto',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Espacinho de instrução pro Lojista do lado sô
            const SizedBox(width: 40),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('💡 Modo de Uso Rápido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 12),
                    Text('1. Conecte sua pistola de código de barras USB no computador.', style: TextStyle(height: 1.4)),
                    SizedBox(height: 8),
                    Text('2. Abra esta tela (o cursor já vai estar piscando no campo certo sô!).', style: TextStyle(height: 1.4)),
                    SizedBox(height: 8),
                    Text('3. Pegue o produto do mercado e bipe.', style: TextStyle(height: 1.4)),
                    SizedBox(height: 8),
                    Text('4. O aliuai busca o nome automático. Você só confere, bota o preço e salva!', style: TextStyle(height: 1.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
