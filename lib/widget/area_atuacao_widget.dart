import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecaoCidadesAtuacao extends StatefulWidget {
  final String lojaId;
  final String cidadeSedeId; // 🏢 Passe o cidade_id atual da loja aqui

  const SecaoCidadesAtuacao({Key? key, required this.lojaId, required this.cidadeSedeId}) : super(key: key);

  @override
  State<SecaoCidadesAtuacao> createState() => _SecaoCidadesAtuacaoState();
}

class _SecaoCidadesAtuacaoState extends State<SecaoCidadesAtuacao> {
  // Guardamos mapas com {'id': 'ID_DO_FIREBASE', 'nome': 'Nome da Cidade - UF'}
  final List<Map<String, String>> _cidadesAdicionais = [];
  final List<Map<String, String>> _bancoDeCidades = [];

  String _nomeCidadeSede = "Carregando...";
  bool _carregando = true;
  bool _salvando = false;
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  Future<void> _inicializarDados() async {
    try {
      // 1. Puxa TODAS as cidades cadastradas no AliUai para o Autocomplete
      QuerySnapshot cidadesSnap = await FirebaseFirestore.instance.collection('cidades').get();
      _bancoDeCidades.clear();
      for (var doc in cidadesSnap.docs) {
        _bancoDeCidades.add({
          'id': doc.id,
          'nome': '${doc['nome']} - ${doc['uf']}', // Ex: "Porto Firme - MG"
        });
      }

      // 2. Descobre o nome da Cidade Sede da loja para exibir fixo na tela
      var sedeMatch = _bancoDeCidades.firstWhere((c) => c['id'] == widget.cidadeSedeId, orElse: () => {'id': '', 'nome': 'Cidade Sede não encontrada'});
      _nomeCidadeSede = '${sedeMatch['nome']}';

      // 3. Carrega o array de ids de expansão da loja
      DocumentSnapshot lojaDoc = await FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).get();

      if (lojaDoc.exists && lojaDoc.data() != null) {
        final dados = lojaDoc.data() as Map<String, dynamic>;
        if (dados['cidades_expansao'] != null) {
          List<String> idsExpansao = List<String>.from(dados['cidades_expansao']);

          setState(() {
            _cidadesAdicionais.clear();
            for (var id in idsExpansao) {
              var cidadeDados = _bancoDeCidades.firstWhere((c) => c['id'] == id, orElse: () => {});
              if (cidadeDados.isNotEmpty) {
                _cidadesAdicionais.add(cidadeDados);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao inicializar cidades: $e");
    } finally {
      setState(() => _carregando = false);
    }
  }

  // 💾 Salva apenas os IDs no array do estabelecimento
  Future<void> _salvarCidades() async {
    setState(() => _salvando = true);
    try {
      List<String> idsParaSalvar = _cidadesAdicionais.map((c) => c['id']!).toList();

      await FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).update({'cidades_expansao': idsParaSalvar});

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expansão regional atualizada! 🚀'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, color: Color(0xFFE65100), size: 28),
                const SizedBox(width: 10),
                const Text("Expansão Regional", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),

            // 🏢 EXIBIÇÃO DA CIDADE SEDE (BLOQUEADA PARA REMOÇÃO)
            const Text(
              "Cidade Sede (Cadastro Principal):",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Chip(
              avatar: const Icon(Icons.business_rounded, color: Color(0xFFE65100), size: 16),
              label: Text(
                "$_nomeCidadeSede (Sede)",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
              ),
              backgroundColor: const Color(0xFFE65100).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE65100)),
              ),
            ),

            const Divider(height: 30),

            // 🔍 AUTOCOMPLETE BUSCANDO DO BANCO DE CIDADES
            Autocomplete<Map<String, String>>(
              displayStringForOption: (option) => option['nome']!,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<Map<String, String>>.empty();

                return _bancoDeCidades.where((cidade) {
                  final mapeada = cidade['nome']!.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  final naoEhSede = cidade['id'] != widget.cidadeSedeId;
                  final naoFoiAdicionada = !_cidadesAdicionais.any((element) => element['id'] == cidade['id']);
                  return mapeada && naoEhSede && naoFoiAdicionada;
                });
              },
              onSelected: (cidadeSelecionada) {
                setState(() {
                  _cidadesAdicionais.add(cidadeSelecionada);
                  _buscaController.clear();
                });
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                _buscaController.text = textController.text;
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: "Adicionar cidade de expansão...",
                    prefixIcon: const Icon(Icons.add_location_alt_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 🏷️ WRAP DE CIDADES ADICIONAIS
            const Text("Cidades Expandidas:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            _cidadesAdicionais.isEmpty
                ? const Text("Nenhuma cidade de expansão adicionada ainda.", style: TextStyle(color: Colors.grey, fontSize: 13))
                : Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _cidadesAdicionais.map((cidade) {
                      return InputChip(
                        label: Text(cidade['nome']!),
                        deleteIcon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.redAccent),
                        onDeleted: () => setState(() => _cidadesAdicionais.remove(cidade)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvarCidades,
                icon: _salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_rounded),
                label: Text(_salvando ? "Salvando..." : "Atualizar Expansão"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
