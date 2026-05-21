import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeLojaController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _carregando = false;
  bool _carregandoCidades = false;
  bool _senhaInvisivel = true;

  String? _estadoSelecionado;
  String? _cidadeSelecionadaId;
  String? _nomeCidadeSelecionada; // Guarda o nome limpo da cidade (ex: "Porto Firme")

  final List<String> _estadosDisponiveis = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  List<Map<String, dynamic>> _cidadesDisponiveis = [];

  @override
  void dispose() {
    _nomeLojaController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // Busca as cidades diretamente e unicamente na API oficial do IBGE
  Future<void> _buscarCidadesDoIBGE(String uf) async {
    setState(() {
      _carregandoCidades = true;
      _cidadeSelecionadaId = null;
      _nomeCidadeSelecionada = null;
      _cidadesDisponiveis = [];
    });

    try {
      final url = Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$uf/municipios');
      final resposta = await http.get(url);

      if (resposta.statusCode == 200) {
        final List<dynamic> dadosIbge = json.decode(resposta.body);

        final List<Map<String, dynamic>> cidadesIbge = dadosIbge.map((cidade) {
          return {
            'id': _gerarSlugId(cidade['nome'].toString()), // ID padrão para o Firebase (ex: porto_firme)
            'nome': '${cidade['nome']}',
          };
        }).toList();

        // Ordena em ordem alfabética
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

  // Transforma textos como "São João del-Rei" em "sao_joao_del_rei" para chaves limpas
  String _gerarSlugId(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  Future<void> _cadastrarParceiro() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cidadeSelecionadaId == null || _nomeCidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione a sua cidade, uai!'), backgroundColor: Colors.amber));
      return;
    }

    setState(() => _carregando = true);

    try {
      String idCidadeFinal;

      // =======================================================================
      // 1. VERIFICAÇÃO ANTI-DUPLICAÇÃO: A cidade já existe com esse nome e UF?
      // =======================================================================
      final cidadesExistentes = await FirebaseFirestore.instance
          .collection('cidades')
          .where('nome', isEqualTo: _nomeCidadeSelecionada)
          .where('uf', isEqualTo: _estadoSelecionado)
          .limit(1) // Só precisamos de uma para comprovar
          .get();

      if (cidadesExistentes.docs.isNotEmpty) {
        // Se já existe, pegamos o ID automático que ela já tem no banco!
        idCidadeFinal = cidadesExistentes.docs.first.id;
        print('Cidade já existia no Aliuai com o ID: $idCidadeFinal');
      } else {
        final novaCidadeRef = FirebaseFirestore.instance.collection('cidades').doc();
        idCidadeFinal = novaCidadeRef.id;
        // 1. SALVA OU ATUALIZA A CIDADE NA COLLECTION DE CIDADES DO FIREBASE
        await novaCidadeRef.set({
          'id': idCidadeFinal,
          'nome': _nomeCidadeSelecionada,
          'uf': _estadoSelecionado,
          'ativo': true, // Garante que fica visível e ativa no ecossistema
        });
      }
      // 2. CRIA O USUÁRIO NO FIREBASE AUTH
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _senhaController.text.trim());

      final uidUsuario = userCredential.user?.uid;

      if (uidUsuario != null) {
        // 3. SALVA OS DADOS DO ESTABELECIMENTO PARCEIRO
        await FirebaseFirestore.instance.collection('estabelecimentos').doc(uidUsuario).set({
          'uid': uidUsuario,
          'nome': _nomeLojaController.text.trim(),
          'cidade_id': idCidadeFinal,
          'email': _emailController.text.trim(),
          'ativo': false,
          'nota': 5.0,
          'tempo_entrega': '30-45 min',
          'is_delivery': false,
          'limite_promocoes': 0,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada com sucesso!'), backgroundColor: Colors.green));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Erro ao cadastrar parceiro.';
      if (e.code == 'email-already-in-use') {
        mensagemErro = 'Este e-mail já está cadastrado em nossa plataforma.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagemErro), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final isDesktop = larguraTela > 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isDesktop ? 450 : larguraTela * 0.9,
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
                  const SizedBox(height: 12),
                  const Text(
                    'Seja um Parceiro aliuai',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cadastre sua empresa e comece a vender em minutos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 28),

                  // NOME DO ESTABELECIMENTO
                  TextFormField(
                    controller: _nomeLojaController,
                    decoration: InputDecoration(
                      labelText: 'Nome do seu Comércio',
                      prefixIcon: const Icon(Icons.store, color: Color(0xFFE65100)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) return 'Informe o nome da sua empresa.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // COMBO ESTADO
                  DropdownButtonFormField<String>(
                    value: _estadoSelecionado,
                    decoration: InputDecoration(
                      labelText: 'Seu Estado (UF)',
                      prefixIcon: const Icon(Icons.map, color: Color(0xFFE65100)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _estadosDisponiveis.map((estado) {
                      return DropdownMenuItem<String>(value: estado, child: Text(estado));
                    }).toList(),
                    onChanged: (uf) {
                      if (uf != null) {
                        setState(() => _estadoSelecionado = uf);
                        _buscarCidadesDoIBGE(uf); // Dispara a busca direta e instantânea no IBGE
                      }
                    },
                    validator: (val) => val == null ? 'Selecione um estado.' : null,
                  ),
                  const SizedBox(height: 16),

                  // COMBO CIDADE (IBGE)
                  _carregandoCidades
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(color: Color(0xFFE65100)),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: _cidadeSelecionadaId,
                          disabledHint: const Text('Selecione primeiro o estado'),
                          decoration: InputDecoration(
                            labelText: 'Sua Cidade',
                            prefixIcon: const Icon(Icons.location_on, color: Color(0xFFE65100)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _estadoSelecionado == null
                              ? null
                              : _cidadesDisponiveis.map((cidade) {
                                  return DropdownMenuItem<String>(value: cidade['id'].toString(), child: Text(cidade['nome'].toString()));
                                }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              final itemSelecionado = _cidadesDisponiveis.firstWhere((c) => c['id'] == id);
                              setState(() {
                                _cidadeSelecionadaId = id;
                                _nomeCidadeSelecionada = itemSelecionado['nome']; // Guarda o nome real
                              });
                            }
                          },
                          validator: (val) => val == null ? 'Selecione uma cidade.' : null,
                        ),
                  const SizedBox(height: 16),

                  // E-MAIL
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail Comercial',
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE65100)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (valor) {
                      if (valor == null || !valor.contains('@')) return 'Informe um e-mail válido.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // SENHA
                  TextFormField(
                    controller: _senhaController,
                    obscureText: _senhaInvisivel,
                    decoration: InputDecoration(
                      labelText: 'Crie uma Senha',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE65100)),
                      suffixIcon: IconButton(icon: Icon(_senhaInvisivel ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _senhaInvisivel = !_senhaInvisivel)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().length < 6) return 'Mínimo de 6 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // BOTÃO DE CONFIRMAR CADASTRO
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _carregando ? null : _cadastrarParceiro,
                      child: _carregando ? const CircularProgressIndicator(color: Colors.white) : const Text('Criar Minha Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BOTÃO VOLTAR PARA O LOGIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Já tem uma conta?'),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                        },
                        child: const Text(
                          'Entrar',
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
    );
  }
}
