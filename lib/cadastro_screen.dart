import 'package:aliuai_painel/home_screen.dart';
import 'package:aliuai_painel/termos_uso_page.dart';
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

  bool _aceitouTermos = false;

  String? _estadoSelecionado;

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

  String gerarSlugEstabelecimento(String texto) {
    String slug = texto.toLowerCase().trim();

    // Substitui espaços por hífen
    slug = slug.replaceAll(RegExp(r'\s+'), '-');

    // Remove acentos e caracteres especiais comuns sô!
    var comAcento = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    var semAcento = 'aaaaaaceeeeiiiinooooouuuuyy';
    for (int i = 0; i < comAcento.length; i++) {
      slug = slug.replaceAll(comAcento[i], semAcento[i]);
    }

    // Remove qualquer caractere que não seja letra, número ou hífen
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\-]'), '');

    // Remove hífens duplicados se houver
    slug = slug.replaceAll(RegExp(r'-+'), '-');

    return slug;
  }

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
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    if (_nomeCidadeSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione a sua cidade, uai!'), backgroundColor: Colors.amber));
      return;
    }

    if (!_aceitouTermos) return;

    setState(() => _carregando = true);

    try {
      String idCidadeFinal;

      final _firestore = FirebaseFirestore.instance;

      // =======================================================================
      // 1. VERIFICAÇÃO ANTI-DUPLICAÇÃO: A cidade já existe com esse nome e UF?
      // =======================================================================
      final cidadesExistentes = await _firestore
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
        final novaCidadeRef = _firestore.collection('cidades').doc();
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

        String idAmigavel = gerarSlugEstabelecimento(_nomeLojaController.text);

        // 2. Checa se já existe um DOCUMENTO com esse ID exato sô
        var docExistente = await _firestore.collection('estabelecimentos').doc(idAmigavel).get();
        // 3. Se o portão estiver fechado (já existe), adiciona o código complementar!
        if (docExistente.exists) {
          // Pode ser um número sequencial, ou um hash curto aleatório sô (ex: 4 dígitos)
          String codigoCurto = DateTime.now().millisecondsSinceEpoch.toString().substring(10);
          idAmigavel = "$idAmigavel-$codigoCurto"; // Viraria: banca-do-nelson-vicosa-452
        }

        String planoInicial = 'indefinido';
        int limiteProdutos = 0;
        int limitePromocoes = 0;
        String statusPagamento = 'pendente';
        // O vencimento padrão seria agora, forçando ele a escolher um plano sô
        DateTime dataVencimento = DateTime.now();

        // 2️⃣ CONSULTA A CONFIGURAÇÃO GLOBAL DO ALIUAI

        final docConfigRef = _firestore.collection('configuracao').doc('ziNL1wNtBbGRWSQHCRzQ');
        final docConfig = await docConfigRef.get();

        bool aplicouCampanhaGratis = false;

        if (docConfig.exists) {
          final dadosConfig = docConfig.data() as Map<String, dynamic>;
          bool isFree = dadosConfig['is_free'] ?? false;
          int diasGratis = dadosConfig['duracao_free_dias'] ?? 30;
          int vagasRestantes = dadosConfig['qtd_free'] ?? 0;

          // 🚀 A MÁGICA DA AUTOMAÇÃO SÔ!
          if (isFree == true && vagasRestantes > 0) {
            planoInicial = 'master'; // Já entra com o plano top!
            limiteProdutos = 100; // Seus limites combinados
            limitePromocoes = 50;
            statusPagamento = 'em_dia';
            dataVencimento = DateTime.now().add(Duration(days: diasGratis));
            aplicouCampanhaGratis = true;
          }
        }

        final batch = _firestore.batch();

        final novaLojaRef = _firestore.collection('estabelecimentos').doc(idAmigavel);

        batch.set(novaLojaRef, {
          'uid': uidUsuario,
          'slug': idAmigavel,
          'nome': _nomeLojaController.text.trim(),
          'cidade_id': idCidadeFinal,
          'email': _emailController.text.trim(),
          'ativo': true,
          'nota': 5.0,
          'tempo_entrega': '30-45 min',
          'is_delivery': false,
          'limite_promocoes': limitePromocoes,
          'limite_produtos': limiteProdutos,
          'plano_atual': planoInicial,
          'status_pagamento': statusPagamento,
          'proximo_vencimento': Timestamp.fromDate(dataVencimento),
        });

        // 📉 SE PEGOU A VAGA, DESCONTA 1 LÁ NA TABELA DE CONFIGURAÇÃO SÔ!
        if (aplicouCampanhaGratis) {
          batch.update(docConfigRef, {
            'qtd_free': FieldValue.increment(-1), // Diminui uma vaga de forma segura no servidor!
          });
        }

        // Manda os dois comandos juntos pro espaço sô!
        await batch.commit();
        if (mounted) {
          // 🚀 LIMPA A ÁRVORE DE TELAS E LEVA DIRETO PARA A HOME SÔ!
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(), // Passa o ID da loja nova sô!
            ),
            (Route<dynamic> route) => false, // Isso aqui apaga a tela de cadastro da memória para ele não voltar nela no botão voltar!
          );

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seja bem-vindo ao Aliuai! Seu painel está pronto sô! 🎉'), backgroundColor: Colors.green));
        }
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada com sucesso!'), backgroundColor: Colors.green));
        //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        // }
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

                  // Garanta que você tem uma lista de strings simples para as cidades sô!
                  // Exemplo: List<String> _cidadesDisponiveis = [];
                  _carregandoCidades
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(color: Color(0xFFE65100)),
                          ),
                        )
                      : Autocomplete<String>(
                          // Define o valor inicial caso o lojista já tenha uma cidade salva no perfil
                          initialValue: TextEditingValue(text: _nomeCidadeSelecionada ?? ''),

                          // 🔍 1. Lógica de filtro: o que acontece quando o usuário digita
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              // 🔥 Extrai apenas os nomes em formato String para o Autocomplete ver
                              return _cidadesDisponiveis.map((cidadeMap) => cidadeMap['nome'].toString());
                            }

                            // Filtra mapeando e transformando em String ao mesmo tempo sô!
                            return _cidadesDisponiveis.map((cidadeMap) => cidadeMap['nome'].toString()).where((String nomeCidade) {
                              return nomeCidade.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },

                          // 🎯 2. O que acontece quando ele clica na cidade filtrada
                          onSelected: (String cidade) {
                            setState(() {
                              _nomeCidadeSelecionada = cidade;
                            });
                          },

                          // 🎨 3. Customização do Campo de Texto onde o usuário digita
                          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Sua Cidade',
                                prefixIcon: const Icon(Icons.location_city, color: Color(0xFFE65100)),
                                // Ícone de lupa/seta para indicar que é um campo de busca sô!
                                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Digite ou selecione uma cidade.';

                                return null;
                              },
                            );
                          },

                          // 🎹 4. Customização da caixinha suspensa (as opções que aparecem flutuando)
                          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF1E1E26), // Mantém o fundo escuro oficial do painel!
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.85, // Ajusta a largura dinamicamente
                                  constraints: BoxConstraints(maxHeight: 250),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[800]!),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                          child: Text(
                                            option,
                                            style: const TextStyle(color: Colors.white, fontSize: 14), // Texto branco no fundo escuro sô
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        activeColor: Colors.orange,
                        value: _aceitouTermos,
                        onChanged: (bool? valor) {
                          setState(() {
                            _aceitouTermos = valor ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Li e estou de acordo com os ', style: TextStyle(fontSize: 13, color: Colors.black)),
                            GestureDetector(
                              onTap: () {
                                // 🚀 Abre a tela de termos para o parceiro ler sô!
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const TermosUsoPage()));
                              },
                              child: const Text(
                                'Termos de Uso do Aliuai.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline, // Deixa o link sublinhado sô
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // BOTÃO DE CONFIRMAR CADASTRO
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300], // 🎨 Garante que ele fique cinza quando bloqueado sô!
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),

                      // 🚨 A FIAÇÃO CORRETA E BLINDADA SÔ:
                      // O botão fica desabilitado (null) APENAS se estiver carregando OU se ele NÃO marcou os termos!
                      onPressed: _carregando || !_aceitouTermos ? null : _cadastrarParceiro,

                      child: _carregando
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Criar Minha Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
