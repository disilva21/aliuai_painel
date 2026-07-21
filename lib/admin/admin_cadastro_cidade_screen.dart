import 'dart:convert';
import 'package:aliuai_painel/services/cidade_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminCidadesTela extends StatefulWidget {
  const AdminCidadesTela({super.key});

  @override
  State<AdminCidadesTela> createState() => _AdminCidadesTelaState();
}

class _AdminCidadesTelaState extends State<AdminCidadesTela> {
  final CidadeService _service = CidadeService();
  String _ufSelecionada = 'MG';
  List<Map<String, dynamic>> _allCidadesDoIBGE = []; // 📦 Guarda a lista bruta
  List<Map<String, dynamic>> _cidadesFiltradas = []; // 🔍 Lista que aparece na tela
  bool _carregandoCidades = false;

  // 🎯 Controller para o campo de busca
  final TextEditingController _buscaController = TextEditingController();

  final List<String> _estados = ['AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'];

  @override
  void initState() {
    super.initState();
    _buscarCidadesDoIBGE();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // 🌍 Puxa a listagem oficial do IBGE
  Future<void> _buscarCidadesDoIBGE() async {
    setState(() {
      _carregandoCidades = true;
      _allCidadesDoIBGE = [];
      _cidadesFiltradas = [];
      _buscaController.clear(); // Limpa a busca ao trocar de estado sô!
    });

    try {
      final url = Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$_ufSelecionada/municipios?orderBy=nome');
      final resposta = await http.get(url);

      if (resposta.statusCode == 200) {
        final List dados = jsonDecode(resposta.body);
        setState(() {
          _allCidadesDoIBGE = dados.map((c) => {'id': c['id'].toString(), 'nome': c['nome'].toString()}).toList();

          // No início, a lista filtrada é idêntica à bruta
          _cidadesFiltradas = List.from(_allCidadesDoIBGE);
        });
      }
    } catch (e) {
      print('Erro ao buscar cidades do IBGE: $e');
    } finally {
      setState(() => _carregandoCidades = false);
    }
  }

  // 🔍 Função mágica que filtra as cidades digitadas em tempo real
  void _filtrarCidades(String query) {
    setState(() {
      if (query.isEmpty) {
        _cidadesFiltradas = List.from(_allCidadesDoIBGE);
      } else {
        _cidadesFiltradas = _allCidadesDoIBGE.where((cidade) {
          final nomeCidade = cidade['nome'].toString().toLowerCase();
          final idCidade = cidade['id'].toString();
          final termoBusca = query.toLowerCase();

          // Deixa o admin buscar tanto pelo nome quanto pelo código do IBGE uai!
          return nomeCidade.contains(termoBusca) || idCidade.contains(termoBusca);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Cobertura de Cidades')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 LINHA DE FILTRO POR ESTADO
            Row(
              children: [
                const Text('Filtrar por Estado: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _ufSelecionada,
                  items: _estados.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                  onChanged: (novoEstado) {
                    if (novoEstado != null) {
                      setState(() => _ufSelecionada = novoEstado);
                      _buscarCidadesDoIBGE();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 🔍 NOVO CAMPO DE BUSCA POR TEXTO
            TextField(
              controller: _buscaController,
              onChanged: _filtrarCidades, // Dispara o filtro a cada letra digitada sô!
              decoration: InputDecoration(
                labelText: 'Buscar cidade por nome ou ID...',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _buscaController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaController.clear();
                          _filtrarCidades('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const Divider(height: 30),

            // 🏛️ LISTAGEM REATIVA COM OS CHECKS
            Expanded(
              child: _carregandoCidades
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<Map<String, bool>>(
                      stream: _service.streamCidadesCadastradasStatus(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final mapaStatusCidades = snapshot.data!;

                        // Se a busca não achar nada sô:
                        if (_cidadesFiltradas.isEmpty) {
                          return const Center(child: Text('Nenhuma cidade encontrada com esse nome sô! 🌾'));
                        }

                        return ListView.builder(
                          // 🎯 IMPORTANTE: Agora renderiza a lista filtrada!
                          itemCount: _cidadesFiltradas.length,
                          itemBuilder: (context, index) {
                            final cidade = _cidadesFiltradas[index];
                            final String idCidade = cidade['id'];
                            final String nomeCidade = cidade['nome'];

                            final bool jaEstaAtivaNoBanco = mapaStatusCidades[idCidade] ?? false;

                            return CheckboxListTile(
                              title: Text(nomeCidade),
                              subtitle: Text(
                                mapaStatusCidades.containsKey(idCidade) ? (jaEstaAtivaNoBanco ? 'Status: Ativa no App' : 'Status: Inativa no App') : 'Status: Não Cadastrada',
                                style: TextStyle(color: mapaStatusCidades.containsKey(idCidade) ? (jaEstaAtivaNoBanco ? Colors.green : Colors.red) : Colors.grey),
                              ),
                              value: jaEstaAtivaNoBanco,
                              activeColor: Colors.orange,
                              onChanged: (bool? valorMarcado) async {
                                if (valorMarcado == true) {
                                  await _service.ativarCidade(idCidade, nomeCidade, _ufSelecionada);
                                } else {
                                  await _service.desativarCidade(idCidade);
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
