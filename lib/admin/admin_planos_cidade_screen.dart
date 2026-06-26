import 'dart:convert';
import 'package:aliuai_painel/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPlanosCidadeScreen extends StatefulWidget {
  const AdminPlanosCidadeScreen({super.key});

  @override
  State<AdminPlanosCidadeScreen> createState() => _AdminPlanosCidadeScreenState();
}

class _AdminPlanosCidadeScreenState extends State<AdminPlanosCidadeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Estados do Formulário sô!
  String? _ufSelecionado;
  String? _idCidadeSelecionada;
  String? _nomeCidadeSelecionada;
  String _planoSelecionado = 'master';

  bool _isFree = false;
  bool _salvando = false;
  bool _carregandoCidades = false;
  bool _modoEdicao = false; // 🔄 Controla se estamos editando um plano existente sô!

  // Lista de cidades vindas do IBGE uai
  List<Map<String, dynamic>> _cidadesDisponiveis = [];

  // Controladores dos parâmetros comerciais sô
  final _qtdFreeController = TextEditingController(text: '50');
  final _duracaoDiasController = TextEditingController(text: '30');
  final _autocompleteController = TextEditingController();

  @override
  void dispose() {
    _qtdFreeController.dispose();
    _duracaoDiasController.dispose();
    _autocompleteController.dispose();
    super.dispose();
  }

  String _gerarSlugId(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9_ ]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> _buscarCidadesDoIBGE(String uf) async {
    setState(() {
      _carregandoCidades = true;
      _idCidadeSelecionada = null;
      if (!_modoEdicao) {
        _nomeCidadeSelecionada = null;
      }

      _cidadesDisponiveis = [];
      if (!_modoEdicao) _autocompleteController.clear();
    });

    try {
      final url = Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios');
      final resposta = await http.get(url);

      if (resposta.statusCode == 200) {
        final List<dynamic> dadosIbge = json.decode(resposta.body);

        final List<Map<String, dynamic>> cidadesIbge = dadosIbge.map((cidade) {
          return {'id': _gerarSlugId(cidade['nome'].toString()), 'nome': '${cidade['nome']}'};
        }).toList();

        cidadesIbge.sort((a, b) => a['nome'].compareTo(b['nome']));

        setState(() {
          _cidadesDisponiveis = cidadesIbge;
          _carregandoCidades = false;
        });
      }
    } catch (e) {
      print('Erro ao buscar cidades no IBGE: $e');
      setState(() => _carregandoCidades = false);
    }
  }

  /// 🚀 Salva ou atualiza a regra comercial sô!
  Future<void> _salvarConfiguracaoCidade() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ufSelecionado == null || _nomeCidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o estado e escolha uma cidade válida sô! 🌾'), backgroundColor: Colors.amber));
      return;
    }

    setState(() => _salvando = true);

    try {
      String idCidadeFinal;

      // =======================================================================
      // 1. SUA LÓGICA MESTRE ANTI-DUPLICAÇÃO: Garante o mesmo ID da coleção cidades sô!
      // =======================================================================
      final cidadesExistentes = await _firestore.collection('cidades').where('nome', isEqualTo: _nomeCidadeSelecionada).where('uf', isEqualTo: _ufSelecionado).limit(1).get();

      if (cidadesExistentes.docs.isNotEmpty) {
        idCidadeFinal = cidadesExistentes.docs.first.id;
        print('Cidade já existia no Aliuai com o ID: $idCidadeFinal');
      } else {
        final novaCidadeRef = _firestore.collection('cidades').doc();
        idCidadeFinal = novaCidadeRef.id;
        await novaCidadeRef.set({'id': idCidadeFinal, 'nome': _nomeCidadeSelecionada, 'uf': _ufSelecionado, 'ativo': true});
        print('Nova cidade cadastrada no ecossistema pelo Admin com ID: $idCidadeFinal');
      }

      await _firestore.collection('planos_cidade').doc(idCidadeFinal).set({
        'cidade_id': idCidadeFinal,
        'nome_cidade': _nomeCidadeSelecionada,
        'uf': _ufSelecionado,
        'plano_id': _planoSelecionado,
        'is_free': _isFree,
        'qtd_free': int.tryParse(_qtdFreeController.text.trim()) ?? 0,
        // Se for edição, o merge cuida para NÃO apagar o contador de consumo do lojista sô!
        if (!_modoEdicao) 'qtd_free_consumido': 0,
        'duracao_free_dias': int.tryParse(_duracaoDiasController.text.trim()) ?? 30,
        'ativo': true,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_modoEdicao ? 'Campanha atualizada com sucesso! 🔄' : 'Nova campanha salva com sucesso! 🚀'), backgroundColor: Colors.green));
        _limparFormulario();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// ✏️ Puxa os dados da lista de volta para o formulário para editar uai!
  void _carregarParaEdicao(Map<String, dynamic> dados, String docId) async {
    setState(() {
      _modoEdicao = true;
      _ufSelecionado = dados['uf'];
      _idCidadeSelecionada = dados['cidade_id'];
      _nomeCidadeSelecionada = dados['nome_cidade'];
      _planoSelecionado = dados['plano_id'] ?? 'master';
      _isFree = dados['is_free'] ?? false;
      _qtdFreeController.text = (dados['qtd_free'] ?? 0).toString();
      _duracaoDiasController.text = (dados['duracao_free_dias'] ?? 30).toString();
      _autocompleteController.text = dados['nome_cidade'] ?? '';
    });

    // Dispara a busca do IBGE para recarregar as opções daquele estado sô!
    await _buscarCidadesDoIBGE(dados['uf']);
    setState(() {
      _idCidadeSelecionada = dados['cidade_id']; // Garante o ID após recarga sô
    });
  }

  /// 🗑️ Passa o rodo e remove a promoção do mapa uai!
  Future<void> _deletarConfiguracao(String docId, String cidadeNome) async {
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar Campanha? 🛑'),
        content: Text('Tem certeza que quer remover a promoção de lançamento de $cidadeNome sô?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _firestore.collection('planos_cidade').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campanha removida com sucesso! 🌾'), backgroundColor: Colors.redAccent));
        }
      } catch (e) {
        print("Erro ao deletar sô: $e");
      }
    }
  }

  void _limparFormulario() {
    setState(() {
      _idCidadeSelecionada = null;
      _nomeCidadeSelecionada = null;
      _isFree = false;
      _modoEdicao = false;
      _qtdFreeController.text = '50';
      _duracaoDiasController.text = '30';
      _autocompleteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final bool isDesktop = larguraTela > 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin - Configurar Planos por Cidade 🚜'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: _salvando
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                  child: Column(
                    children: [
                      // =======================================================================
                      // FORMULÁRIO DE CADASTRO/EDIÇÃO SÔ!
                      // =======================================================================
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _modoEdicao ? '✏️ Editando Promoção Regional' : 'Lançamento de Promoção Regional 🎁',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    if (_modoEdicao)
                                      TextButton.icon(
                                        onPressed: _limparFormulario,
                                        icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                        label: const Text('Cancelar Edição', style: TextStyle(color: Colors.red)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('Defina regras comerciais exclusivas para novos cadastros de uma cidade do IBGE sô.', style: TextStyle(color: Colors.grey)),
                                const Divider(height: 32),

                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 1, child: _buildDropdownUF()),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 2, child: _buildAutocompleteCidades()),
                                    ],
                                  )
                                else ...[
                                  _buildDropdownUF(),
                                  const SizedBox(height: 16),
                                  _buildAutocompleteCidades(),
                                ],

                                const SizedBox(height: 16),
                                _buildDropdownPlano(),

                                const Divider(height: 40),
                                const Text('Configurações da Campanha ⚙️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),

                                SwitchListTile(
                                  title: const Text('Ativar Gratuidade de Lançamento?'),
                                  subtitle: const Text('Se marcado, novos cadastros desta cidade ganham cortesia.'),
                                  value: _isFree,
                                  activeColor: Colors.green,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) => setState(() => _isFree = val),
                                ),

                                const SizedBox(height: 16),

                                if (isDesktop)
                                  Row(
                                    children: [
                                      Expanded(child: _buildInputQtdFree()),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildInputDiasGratis()),
                                    ],
                                  )
                                else ...[
                                  _buildInputQtdFree(),
                                  const SizedBox(height: 16),
                                  _buildInputDiasGratis(),
                                ],

                                const SizedBox(height: 32),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: _salvarConfiguracaoCidade,
                                    icon: Icon(_modoEdicao ? Icons.update : Icons.save),
                                    label: Text(_modoEdicao ? 'Atualizar Regra sô!' : 'Salvar Regra da Cidade sô!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =======================================================================
                      // 📋 LISTAGEM EM TEMPO REAL DAS CAMPANHAS ATIVAS UAI!
                      // =======================================================================
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                          child: Text(
                            'Campanhas Configuradas no AliUai 🌾',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E26)),
                          ),
                        ),
                      ),
                      _buildListaCampanhasAtivas(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ===========================================================================
  // WIDGET DE LISTAGEM REATIVA SÔ!
  // ===========================================================================
  Widget _buildListaCampanhasAtivas() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('planos_cidade').orderBy('atualizadoEm', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('Nenhuma promoção regional ativa no momento sô! 🗺️')),
            ),
          );
        }

        var docsPromo = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Evita briga de scroll sô!
          itemCount: docsPromo.length,
          itemBuilder: (context, index) {
            var doc = docsPromo[index];
            var dados = doc.data() as Map<String, dynamic>;

            String cidadeNome = dados['nome_cidade'] ?? 'Cidade Indefinida';
            String uf = dados['uf'] ?? '--';
            String plano = dados['plano_id'] ?? 'master';
            bool isFree = dados['is_free'] ?? false;
            int totalVagas = dados['qtd_free'] ?? 0;
            int consumo = dados['qtd_free_consumido'] ?? 0;
            int diasCortesia = dados['duracao_free_dias'] ?? 30;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isFree ? Colors.green[100] : Colors.grey[200],
                  child: Icon(isFree ? Icons.card_giftcard : Icons.monetization_on, color: isFree ? Colors.green : Colors.grey),
                ),
                title: Text('$cidadeNome - $uf', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: isFree
                    ? Text('Plano: ${plano.toUpperCase()} • 🎁 $diasCortesia dias grátis\n📊 Vagas: $consumo ocupadas de $totalVagas')
                    : Text('Plano: ${plano.toUpperCase()} • Valor customizado da cidade'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _carregarParaEdicao(dados, doc.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deletarConfiguracao(doc.id, cidadeNome),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SELETORES E INPUTS COMPONENTIZADOS SÔ
  // ===========================================================================

  Widget _buildDropdownUF() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Selecione a UF', border: OutlineInputBorder()),
      value: _ufSelecionado,
      items: Utils.estadosDisponiveis.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _ufSelecionado = value);
          _buscarCidadesDoIBGE(value);
        }
      },
    );
  }

  Widget _buildAutocompleteCidades() {
    if (_ufSelecionado == null) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(labelText: 'Cidade', hintText: 'Selecione a UF primeiro...', border: OutlineInputBorder()),
      );
    }

    if (_carregandoCidades) {
      return const Padding(
        padding: EdgeInsets.only(top: 12.0),
        child: Center(child: LinearProgressIndicator(color: Colors.green)),
      );
    }

    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _autocompleteController,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        return _cidadesDisponiveis.where((Map<String, dynamic> cidade) {
          return cidade['nome'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      displayStringForOption: (Map<String, dynamic> option) => option['nome'],
      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Cidade (Digite para buscar)',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.search, color: Colors.grey),
          ),
          validator: (value) {
            if (_idCidadeSelecionada == null) return 'Escolha uma cidade da lista sô! 📍';
            return null;
          },
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<Map<String, dynamic>> onSelected, Iterable<Map<String, dynamic>> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 800 ? 460 : MediaQuery.of(context).size.width - 48,
              height: 180.0,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> option = options.elementAt(index);
                  return ListTile(
                    title: Text(option['nome']),
                    onTap: () {
                      onSelected(option);
                      setState(() {
                        _idCidadeSelecionada = option['id'];
                        _nomeCidadeSelecionada = option['nome'];
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownPlano() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Plano Beneficiado', border: OutlineInputBorder()),
      value: _planoSelecionado,
      items: const [
        DropdownMenuItem(value: 'inicial', child: Text('Plano Vitrine')),
        DropdownMenuItem(value: 'intermediario', child: Text('Plano Expansão')),
        DropdownMenuItem(value: 'master', child: Text('Plano Master')),
      ],
      onChanged: (value) => setState(() => _planoSelecionado = value ?? 'master'),
    );
  }

  Widget _buildInputQtdFree() {
    return TextFormField(
      controller: _qtdFreeController,
      enabled: _isFree,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Quantidade de Vagas Grátis:', border: OutlineInputBorder()),
      validator: (val) {
        if (_isFree && (val == null || val.trim().isEmpty)) return 'Insira a quantidade uai!';
        return null;
      },
    );
  }

  Widget _buildInputDiasGratis() {
    return TextFormField(
      controller: _duracaoDiasController,
      enabled: _isFree,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Duração da Cortesia (Dias):', border: OutlineInputBorder()),
      validator: (val) {
        if (_isFree && (val == null || val.trim().isEmpty)) return 'Insira a duração sô!';
        return null;
      },
    );
  }
}
