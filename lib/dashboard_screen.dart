import 'dart:convert';

import 'package:aliuai_painel/caderneta_fiado_screen.dart';
import 'package:aliuai_painel/gerenciar_eventos_screen.dart';
import 'package:aliuai_painel/metrica_screen.dart';
import 'package:aliuai_painel/onboarding_dialog.dart';
import 'package:aliuai_painel/pedidos_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// Importações das suas telas filhas
import 'produtos_screen.dart';
import 'promocoes_screen.dart';
import 'perfil_store_screen.dart';
import 'planos_screen.dart';
import 'seguranca_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _abaSelecionada = 0;
  String? _lojaIdReal; // Guarda o ID automático real do Firestore (ex: ABCDE123)
  bool _carregandoDadosLoja = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _primeiraCarga = true;
  bool _somAtivado = true;

  // Variáveis de controle do motor financeiro / banner
  String _statusPagamentoGeral = 'pendente';
  int _diasRestantesParaVencer = 0;
  bool _mostrarBannerPeriodoDeGraca = false;

  final List<bool> _abasCarregadas = List.generate(9, (index) => false);

  @override
  void initState() {
    super.initState();
    _inicializarPainel();
    _verificarPrimeiroAcesso();
    _escutarNovosPedidos();

    // carregarPlanosIniciaisEmDev();
  }

  Future<void> carregarPlanosIniciaisEmDev() async {
    final firestoreDev = FirebaseFirestore.instance;
    final batch = firestoreDev.batch();

    await MigradorCategoriasAliuai.exportarCategoriasDeProdParaJson();

    // 🗺️ O mapa dos seus planos oficiais sô! Ajuste os valores se precisar:
    final List<Map<String, dynamic>> novosPlanos = [
      {
        'ordem': 1,
        'limite_produtos': 0,
        'limite_promocoes': 0,
        'descricao': 'Marque sua presença no mapa. Ideal para estabelecimentos que querem ser encontrados por novos clientes.',
        'id': 'inicial',
        'valor': 24.9,
        'nome': 'Plano Vitrine',
        'beneficios': ['Exibe o estabelecimento no app', 'Cadastro de Eventos', 'Suporte via WhatsApp'],
        'ativo': true,
        'valor_promocional': 19.9,
      },
      {
        'limite_produtos': 50,
        'ordem': 2,
        'limite_promocoes': 10,
        'descricao': 'Perfeito para lojas que precisam cadastrar seu cardápio completo, criar promoções e aumentar o volume de vendas diárias.',
        'id': 'intermediario',
        'valor': 39.9,
        'beneficios': ['Exibe o estabelecimento no app', 'Cadastre até 50 produtos', 'Cadastre até 10 promoções', 'Painel de Pedidos', 'Cadastro de Eventos', 'Suporte via WhatsApp'],
        'nome': 'Plano Expansão',
        'ativo': true,
        'valor_promocional': 34.9,
      },
      {
        'ordem': 3,
        'limite_produtos': 100,
        'limite_promocoes': 50,
        'descricao': 'Para negócios consolidados que buscam máxima visibilidade na busca do app, suporte prioritário e ferramentas avançadas.',
        'id': 'master',
        'valor': 59.9,
        'nome': 'Plano Master',
        'beneficios': [
          'Exibe o estabelecimento no app',
          'Cadastre até 100 produtos',
          'Cadastre até 50 promoções',
          'Painel de Pedidos',
          'Métricas e Gráficos',
          'Cadastro de Eventos',
          'Cardeneta de Fiado',
          'Suporte prioritário via WhatsApp',
        ],
        'ativo': true,
        'valor_promocional': 49.9,
      },
    ];

    try {
      print('🔄 Injetando a coleção "planos" na base de DEV...');

      for (var plano in novosPlanos) {
        final docRef = firestoreDev.collection('planos').doc(plano['id']);

        batch.set(docRef, {
          'id': plano['id'],
          'ordem': plano['ordem'],
          'nome': plano['nome'],
          'valor': plano['valor'],
          'valor_promocional': plano['valor_promocional'],
          'beneficios': plano['beneficios'] as List,
          'limite_produtos': plano['limite_produtos'],
          'limite_promocoes': plano['limite_promocoes'],
          'ativo': plano['ativo'],
          'descricao': plano['descricao'],
        });
      }

      await batch.commit();
      print('🚀 [SUCESSO TOTAL] Coleção de planos criada e sincronizada em DEV sô!');
    } catch (e) {
      print('❌ Erro ao salvar planos em DEV sô: $e');
    }
  }

  Future<void> clonarColecaoPlanosDeProdParaDev() async {
    // 🚨 ATENÇÃO SÔ: Para esse script rodar, você precisa inicializar temporariamente
    // o Firebase apontando para o projeto de PRODUÇÃO para buscar os dados primeiro!

    final firestoreProd = FirebaseFirestore.instance; // Instância atual (conectada em PROD)

    try {
      print('🔄 Buscando os planos oficiais lá na base de Produção...');

      // 1. Puxa todos os documentos da coleção "planos" de PROD sô
      final snapshotProd = await firestoreProd.collection('planos').get();

      if (snapshotProd.docs.isEmpty) {
        print('⚠️ Nenhum plano encontrado na base de produção sô!');
        return;
      }

      print('📦 Encontrou ${snapshotProd.docs.length} planos. Prepare os dados...');

      // 2. Transforma os documentos em uma lista de mapas para não perder nada sô!
      List<Map<String, dynamic>> dadosDosPlanos = [];
      for (var doc in snapshotProd.docs) {
        final dados = doc.data();
        // Guardamos o ID do documento para manter o mesmo ID em DEV sô!
        dados['id_documento_original'] = doc.id;
        dadosDosPlanos.add(dados);
      }

      print('--------------------------------------------------');
      print('🚨 PASSO CRUCIAL SÔ:');
      print('1. Pare a execução do app agora.');
      print('2. Mude as chaves de inicialização do Firebase para o seu projeto de DEV.');
      print('3. Cole a lista de mapas abaixo no método de gravação que vou te mostrar!');
      print('--------------------------------------------------');

      // Imprime no console em formato JSON/Mapa para você copiar sô!
      for (var plano in dadosDosPlanos) {
        print('PLANO_DADO: $plano');
      }
    } catch (e) {
      print('❌ Erro ao ler dados de produção sô: $e');
    }
  }

  void _escutarNovosPedidos() {
    FirebaseFirestore.instance
        .collection('pedidos')
        .where('estabelecimento_id', isEqualTo: _lojaIdReal)
        .where('status', isEqualTo: 'pendente') // Filtra apenas pedidos novos sô!
        .snapshots()
        .listen((snapshot) async {
          // 🎯 Se for a primeira vez que a tela abre, o Firestore traz o histórico.
          // Ignoramos a primeira carga para o painel não começar apitando igual doido sô!
          if (_primeiraCarga) {
            _primeiraCarga = false;
            return;
          }

          // 🔥 Se o snapshot teve modificações e alguma delas foi um documento ADICIONADO:
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              try {
                // Toca o som do alerta!
                if (_somAtivado) {
                  try {
                    await _audioPlayer.play(AssetSource('sounds/notificacao.mp3'));
                  } catch (e) {
                    print("Erro ao tocar som sô: $e");
                  }
                }
              } catch (e) {
                print("Erro ao tocar som sô: $e");
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Limpa o player da memória sô!
    super.dispose();
  }

  Future<void> _verificarPrimeiroAcesso() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool primeiroAcesso = prefs.getBool('primeiro_acesso_painel') ?? true;

    if (primeiroAcesso && mounted) {
      await prefs.setBool('primeiro_acesso_painel', false); // 🔥 Corrigido para false para salvar que já viu sô!
      OnboardingDialog.mostrar(context);
    }
  }

  /// 🔥 Fonte Única da Verdade: Busca os dados uma única vez e distribui
  Future<void> _inicializarPainel() async {
    try {
      // await MigradorCategoriasAliuai.exportarCategoriasDeProdParaJson();

      // String meuJsonDeProd =
      //     '[{"nome":"Distribuidoras & Bebidas","ordem":6,"cor":"#FFB300","icone":"sports_bar","id_documento_original":"cat_bebidas"},{"icone":"event_available_rounded","nome":"Eventos","cor":"#7B1FA2","ordem":8,"id_documento_original":"cat_eventos"},{"nome":"Farmácias","ordem":2,"cor":"#1E88E5","icone":"local_pharmacy","id_documento_original":"cat_farmacias"},{"icone":"home_repair_service","nome":"Material de Construção","cor":"#E65100","ordem":6,"id_documento_original":"cat_material_construcao"},{"icone":"shopping_basket","nome":"Mercados","cor":"#43A047","ordem":3,"id_documento_original":"cat_mercados"},{"nome":"Moda & Beleza","cor":"#D81B60","ordem":7,"icone":"checkroom","id_documento_original":"cat_moda"},{"nome":"Restaurantes","ordem":1,"cor":"#E53935","icone":"restaurant","id_documento_original":"cat_restaurantes"},{"icone":"build","nome":"Serviços","cor":"#546E7A","ordem":4,"id_documento_original":"cat_servicos"},{"nome":"Utilidades","cor":"#00897B","ordem":50,"icone":"info","id_documento_original":"cat_utilidades"}]';
      // await MigradorCategoriasAliuai.importarJsonParaDev(meuJsonDeProd);

      // await MigradorSecoesCardapio.exportarCategoriaProdutoDeProdParaJson();

      // String meuJsonDeProdutos =
      //     '[{"id":"3SYDzsUtpcsIeW0XOCTl","ativo":true,"slug":"racoes_e_alimentos_pet","estabelecimentos_permitidos":["cat_mercados","cat_utilidades","cat_servicos"],"nome":"Rações & Alimentos Pet","id_documento_original":"3SYDzsUtpcsIeW0XOCTl"},{"id":"531MEeEaaK0HpC1de5L4","nome":"Hortifrúti","slug":"hortifruti","estabelecimentos_permitidos":["cat_mercados","cat_utilidades"],"ativo":true,"id_documento_original":"531MEeEaaK0HpC1de5L4"},{"nome":"Informática & Periféricos","slug":"informatica_e_perifericos","estabelecimentos_permitidos":["cat_utilidades","cat_servicos"],"ativo":true,"id":"5lbF6MqTaQ6wUJ4PSDEf","id_documento_original":"5lbF6MqTaQ6wUJ4PSDEf"},{"slug":"moda_feminina","estabelecimentos_permitidos":["cat_moda_beleza","cat_utilidades"],"nome":"Moda Feminina","ativo":true,"id":"5ldyxduNYzTn0sCYBnFu","id_documento_original":"5ldyxduNYzTn0sCYBnFu"},{"nome":"Bebidas","slug":"bebidas","estabelecimentos_permitidos":["cat_restaurantes","cat_distribuidora_bebidas","cat_mercados","cat_utilidades"],"ativo":true,"id":"6XAC30P80474tiZPGUOk","id_documento_original":"6XAC30P80474tiZPGUOk"},{"ativo":true,"slug":"porcoes","estabelecimentos_permitidos":["cat_restaurantes","cat_distribuidora_bebidas"],"nome":"Porções","id":"C6VEQXoGDRBbqnKtvhDb","id_documento_original":"C6VEQXoGDRBbqnKtvhDb"},{"id":"F68uAQYFN6uKnWgU9NFT","slug":"acessorios_e_brinquedos_pet","estabelecimentos_permitidos":["cat_utilidades","cat_servicos"],"nome":"Acessórios & Brinquedos Pet","ativo":true,"id_documento_original":"F68uAQYFN6uKnWgU9NFT"},{"ativo":true,"slug":"gas_e_agua_mineral","estabelecimentos_permitidos":["cat_distribuidora_bebidas","cat_mercados","cat_utilidades"],"nome":"Gás & Água Mineral","id":"PNcjFIkHKJEBVRhlrmiA","id_documento_original":"PNcjFIkHKJEBVRhlrmiA"},{"slug":"sobremesas","estabelecimentos_permitidos":["cat_restaurantes","cat_mercados","cat_utilidades"],"nome":"Sobremesas","ativo":true,"id":"RHSLckBqGvY2HWMWo3qr","id_documento_original":"RHSLckBqGvY2HWMWo3qr"},{"slug":"moda_masculina","estabelecimentos_permitidos":["cat_moda_beleza","cat_utilidades"],"nome":"Moda Masculina","ativo":true,"id":"So8GszDo9JDyBW4mmE5T","id_documento_original":"So8GszDo9JDyBW4mmE5T"},{"slug":"perfumaria","estabelecimentos_permitidos":["cat_moda_beleza","cat_farmacias","cat_utilidades"],"nome":"Perfumaria","ativo":true,"id":"V9JKtzV1GgCYDz7WW4Wy","id_documento_original":"V9JKtzV1GgCYDz7WW4Wy"},{"id":"WV3nHVR2MNB4U8BoPG0l","slug":"medicamentos_veterinarios","estabelecimentos_permitidos":["cat_farmacias","cat_servicos"],"nome":"Medicamentos Veterinários","ativo":true,"id_documento_original":"WV3nHVR2MNB4U8BoPG0l"},{"id":"WjTYPgvBlmzpW3IKGsLU","ativo":true,"nome":"Carregadores & Cabos","slug":"carregadores_e_cabos","estabelecimentos_permitidos":["cat_utilidades","cat_mercados","cat_distribuidora_bebidas"],"id_documento_original":"WjTYPgvBlmzpW3IKGsLU"},{"id":"XxBxKBrE2js30ICFYk78","slug":"bijuterias_e_acessorios","estabelecimentos_permitidos":["cat_moda_beleza","cat_eventos","cat_utilidades"],"nome":"Bijuterias & Acessórios","ativo":true,"id_documento_original":"XxBxKBrE2js30ICFYk78"},{"nome":"Pizzas & Massas","slug":"pizzas_e_massas","estabelecimentos_permitidos":["cat_restaurantes"],"ativo":true,"id":"aovhnl78qAqWqGWgeQ9i","id_documento_original":"aovhnl78qAqWqGWgeQ9i"},{"id":"bxko6C0snDLN9Y51k3Jh","nome":"Capas & Películas de Celular","estabelecimentos_permitidos":["cat_utilidades","cat_servicos"],"slug":"capas_e_peliculas_de_celular","ativo":true,"id_documento_original":"bxko6C0snDLN9Y51k3Jh"},{"id":"c506i0OzSsWTbTZJOP1Q","nome":"Roupas Íntimas / Lingerie","estabelecimentos_permitidos":["cat_moda_beleza"],"slug":"roupas_intimas___lingerie","ativo":true,"id_documento_original":"c506i0OzSsWTbTZJOP1Q"},{"id":"cEy6WKHfOiCDDhFd2sFK","slug":"suplementos_e_vitaminas","estabelecimentos_permitidos":["cat_farmacias","cat_mercados"],"nome":"Suplementos & Vitaminas","ativo":true,"id_documento_original":"cEy6WKHfOiCDDhFd2sFK"},{"slug":"refeicoes___prato_feito","estabelecimentos_permitidos":["cat_restaurantes"],"nome":"Refeições / Prato Feito","ativo":true,"id":"cSsfWtPW4Ig10tktgzRg","id_documento_original":"cSsfWtPW4Ig10tktgzRg"},{"id":"d3IZ1pOZBjucHfwXUfjY","slug":"higiene_pessoal","estabelecimentos_permitidos":["cat_farmacias","cat_mercados","cat_utilidades"],"nome":"Higiene Pessoal","ativo":true,"id_documento_original":"d3IZ1pOZBjucHfwXUfjY"},{"id":"kFfN9PRDect7e4P7VvdI","ativo":true,"slug":"fones_e_caixas_de_som","estabelecimentos_permitidos":["cat_utilidades","cat_eventos"],"nome":"Fones & Caixas de Som","id_documento_original":"kFfN9PRDect7e4P7VvdI"},{"slug":"decoracao_e_tapetes","estabelecimentos_permitidos":["cat_material_construcao","cat_eventos","cat_utilidades"],"nome":"Decoração & Tapetes","ativo":true,"id":"oKJNDuLXNyjWr2CK0oLg","id_documento_original":"oKJNDuLXNyjWr2CK0oLg"},{"nome":"Cama, Mesa & Banho","estabelecimentos_permitidos":["cat_material_construcao","cat_utilidades"],"slug":"cama_mesa_e_banho","ativo":true,"id":"oZtGPAsDpqKlpKBiDEoC","id_documento_original":"oZtGPAsDpqKlpKBiDEoC"},{"estabelecimentos_permitidos":["cat_restaurantes","cat_utilidades"],"slug":"pasteis_e_salgados","nome":"Pastéis & Salgados","ativo":true,"id":"ojOrRxuXd9C5sDIZCJqa","id_documento_original":"ojOrRxuXd9C5sDIZCJqa"},{"ativo":true,"slug":"moda_infantil___enxoval","estabelecimentos_permitidos":["cat_moda_beleza","cat_utilidades"],"nome":"Moda Infantil / Enxoval","id":"qN6qDK6jZBzE8u9F69uq","id_documento_original":"qN6qDK6jZBzE8u9F69uq"},{"ativo":true,"nome":"Ferramentas & Materiais Elétricos","slug":"ferramentas_e_materiais_eletricos","estabelecimentos_permitidos":["cat_material_construcao","cat_utilidades"],"id":"t160vKuSmDpWgeU4BMHo","id_documento_original":"t160vKuSmDpWgeU4BMHo"},{"id":"tC7upEPauCPDounCq6Qa","estabelecimentos_permitidos":["cat_moda_beleza","cat_utilidades"],"slug":"calcados_e_tenis","nome":"Calçados & Tênis","ativo":true,"id_documento_original":"tC7upEPauCPDounCq6Qa"},{"slug":"outros","estabelecimentos_permitidos":["cat_restaurantes","cat_farmacias","cat_mercados","cat_servicos","cat_distribuidora_bebidas","cat_material_construcao","cat_moda_beleza","cat_eventos","cat_utilidades"],"nome":"Outros","ativo":true,"id":"wVomUxXF3BsxYWD4I3Wr","id_documento_original":"wVomUxXF3BsxYWD4I3Wr"},{"ativo":true,"nome":"Lanches","slug":"lanches","estabelecimentos_permitidos":["cat_restaurantes","cat_distribuidora_bebidas","cat_utilidades"],"id":"wtTCDYZY1Kk50IeSSFzZ","id_documento_original":"wtTCDYZY1Kk50IeSSFzZ"},{"ativo":true,"slug":"cosmeticos_e_maquiagem","estabelecimentos_permitidos":["cat_moda_beleza","cat_farmacias","cat_utilidades"],"nome":"Cosméticos & Maquiagem","id":"yC3QuSMnAm8MKejUE1Nx","id_documento_original":"yC3QuSMnAm8MKejUE1Nx"}]';

      // await MigradorSecoesCardapio.importarCategoriaProdutoParaDev(meuJsonDeProdutos);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance.collection('estabelecimentos').where('uid', isEqualTo: user.uid).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        final docLoja = querySnapshot.docs.first;
        final dadosLoja = docLoja.data();

        _lojaIdReal = docLoja.id;

        _statusPagamentoGeral = dadosLoja['status_pagamento'] ?? 'pendente';
        // 1. Pegamos o dado bruto do mapa sem tipar ainda sô
        final dynamic dadoVencimento = dadosLoja['proximo_vencimento'];

        Timestamp? timestampVencimento;

        // 2. Fazemos a checagem mágica para blindar o app:
        if (dadoVencimento is Timestamp) {
          // Se já for Timestamp, perfeito sô!
          timestampVencimento = dadoVencimento;
        } else if (dadoVencimento is String) {
          // 🛡️ Se for a String ISO, convertemos para DateTime e depois para Timestamp!
          final dateTimeConvertido = DateTime.tryParse(dadoVencimento);
          if (dateTimeConvertido != null) {
            timestampVencimento = Timestamp.fromDate(dateTimeConvertido);
          }
        }

        if (_statusPagamentoGeral == 'isento') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 999;
        } else if (_statusPagamentoGeral == 'teste') {
          _mostrarBannerPeriodoDeGraca = false;
          _diasRestantesParaVencer = 7;
        } else if (_statusPagamentoGeral == 'pendente') {
          _mostrarBannerPeriodoDeGraca = true;
          _diasRestantesParaVencer = 0;
          _abaSelecionada = 6; // Redireciona para os planos sô
        } else {
          if (timestampVencimento != null) {
            final dataVencimento = timestampVencimento.toDate();
            final dataHoje = DateTime.now();

            final hojeApenasData = DateTime(dataHoje.year, dataHoje.month, dataHoje.day);
            final vencimentoApenasData = DateTime(dataVencimento.year, dataVencimento.month, dataVencimento.day);

            _diasRestantesParaVencer = vencimentoApenasData.difference(hojeApenasData).inDays;

            if (_diasRestantesParaVencer <= 7 || _statusPagamentoGeral == 'atrasado') {
              _mostrarBannerPeriodoDeGraca = true;
            } else {
              _mostrarBannerPeriodoDeGraca = false;
            }
          } else {
            _mostrarBannerPeriodoDeGraca = false;
          }
        }
      }
    } catch (e) {
      print('Erro ao inicializar painel central da Dashboard: $e');
    }

    if (mounted) {
      setState(() => _carregandoDadosLoja = false);
    }
  }

  /// Método para abrir o fluxo de pagamento
  void _abrirModalPagamentoPix() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pix, color: Colors.teal),
            SizedBox(width: 12),
            Text('Ativação / Renovação Pix'),
          ],
        ),
        content: const Text('Visite a tela de planos para escolher o plano ideal para sua loja e efetuar o pagamento via Pix.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _abaSelecionada = 6; // Mirando o index correto da PlanosScreen sô!
              });
            },
            child: const Text('Visitar Agora', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  /// 🛠️ SEU MÉTODO DE CONSTRUÇÃO DO ITEM DE MENU RECUPERADO AQUI SÔ!
  Widget _buildItemMenu({required int index, required String titulo, required IconData icone}) {
    final bool selecionado = _abaSelecionada == index;
    final bool ehCelular = MediaQuery.of(context).size.width < 800;

    return ListTile(
      selected: selecionado,
      selectedTileColor: Colors.white.withOpacity(0.05),
      leading: Icon(icone, color: selecionado ? const Color(0xFFE65100) : Colors.grey),
      title: Text(
        titulo,
        style: TextStyle(color: selecionado ? Colors.white : Colors.grey, fontWeight: selecionado ? FontWeight.bold : FontWeight.normal),
      ),
      onTap: () {
        setState(() {
          _abaSelecionada = index;
        });

        if (ehCelular) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoDadosLoja) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
      );
    }

    // 🔥 Ativa o carregamento da aba atual no momento do clique sô!
    _abasCarregadas[_abaSelecionada] = true;

    final bool ehCelular = MediaQuery.of(context).size.width < 800;
    bool contaBloqueadaOuAtrasada = _statusPagamentoGeral == 'atrasado' || (_statusPagamentoGeral != 'isento' && _diasRestantesParaVencer < 0);
    bool contaNovaPendente = _statusPagamentoGeral == 'pendente';

    Widget construirMenuCompleto() {
      return Container(
        width: 250,
        color: const Color(0xFF1E1E26),
        child: ListView(
          children: [
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Painel aliuai',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            _buildItemMenu(index: 0, titulo: 'Dashboard', icone: Icons.analytics_outlined), // Alterado ícone para combinar com Métricas sô!
            lineDivider(),
            _buildItemMenu(index: 1, titulo: 'Pedidos', icone: Icons.delivery_dining_rounded),
            lineDivider(),
            _buildItemMenu(index: 2, titulo: 'Produtos', icone: Icons.shopping_bag_outlined),
            lineDivider(),
            _buildItemMenu(index: 3, titulo: 'Promoções', icone: Icons.local_offer_outlined),
            lineDivider(),
            _buildItemMenu(index: 4, titulo: 'Eventos', icone: Icons.add_location_alt_outlined),
            lineDivider(),
            _buildItemMenu(index: 5, titulo: 'Meu Perfil', icone: Icons.storefront_outlined),
            lineDivider(),
            _buildItemMenu(index: 6, titulo: 'Planos de Assinatura', icone: Icons.rocket_launch_outlined),
            lineDivider(),
            _buildItemMenu(index: 7, titulo: 'Cardeneta Fiado', icone: Icons.menu_book_rounded),
            lineDivider(),
            _buildItemMenu(index: 8, titulo: 'Segurança', icone: Icons.lock_outline),
            lineDivider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  if (ehCelular) Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: ehCelular ? Drawer(child: construirMenuCompleto()) : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 🔔 Botão de Ligar/Desligar Som Estilizado
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              // Muda o ícone dependendo do estado sô!
              icon: Icon(_somAtivado ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
              // Se estiver ligado fica Verde, se estiver mutado fica Cinza ou Vermelho
              style: IconButton.styleFrom(backgroundColor: _somAtivado ? Colors.green : Colors.grey[600]),
              tooltip: _somAtivado ? 'Desativar som dos pedidos' : 'Ativar som dos pedidos',
              onPressed: () {
                setState(() {
                  _somAtivado = !_somAtivado; // 🔥 Inverte o estado ao clicar sô!
                });

                // Uma mensagem rápida no rodapé para confirmar a ação do lojista
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_somAtivado ? 'Alertas sonoros ativados! 🔊' : 'Painel silenciado! 🔇'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: _somAtivado ? Colors.green : Colors.black87,
                  ),
                );
              },
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          if (_statusPagamentoGeral != 'isento' && _mostrarBannerPeriodoDeGraca)
            InkWell(
              onTap: _abrirModalPagamentoPix,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                color: contaBloqueadaOuAtrasada ? Colors.red[700] : Colors.orange[700],
                child: Row(
                  children: [
                    Icon(contaBloqueadaOuAtrasada ? Icons.gavel_rounded : Icons.star_border_purple500_rounded, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contaBloqueadaOuAtrasada
                                ? 'MENSALIDADE VENCIDA - Efetue o pagamento para evitar a suspensão da sua loja!'
                                : contaNovaPendente
                                ? 'BEM-VINDO AO ALIUAI! 🎉 Sua conta está aguardando ativação.'
                                : 'RENOVAÇÃO DO PLANO - Sua mensalidade vence em $_diasRestantesParaVencer ${_diasRestantesParaVencer == 1 ? 'dia' : 'dias'}.',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            contaNovaPendente
                                ? 'Clique aqui para pagar a primeira mensalidade e liberar seu catálogo para os clientes.'
                                : 'Clique aqui para visualizar a chave Pix e manter o seu painel ativo.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

          Expanded(
            child: Row(
              children: [
                if (!ehCelular) construirMenuCompleto(),

                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(ehCelular ? 8 : 16),
                    // 🛡️ O INDEXED STACK SEGURO E ECONÔMICO PLUGADO E PREPARADO!
                    child: IndexedStack(
                      index: _abaSelecionada,
                      children: [
                        _abasCarregadas[0] ? MetricaScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[1] ? PedidosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        // _abasCarregadas[2] ? ProdutosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[2] ? ProdutosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[3] ? PromocoesScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[4] ? GerenciarEventosPage(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[5] ? PerfilStoreScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[6] ? PlanosScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[7] ? CadernetaFiadoScreen(lojaId: _lojaIdReal!) : const SizedBox.shrink(),
                        _abasCarregadas[8] ? const SegurancaScreen() : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Padding lineDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Divider(color: Colors.white10, height: 1),
    );
  }
}

class MigradorCategoriasAliuai {
  // ===========================================================================
  // 1º PASSO: RODE EM PROD (Para extrair o JSON oficial sô!)
  // ===========================================================================
  static Future<void> exportarCategoriasDeProdParaJson() async {
    final firestoreProd = FirebaseFirestore.instance;

    try {
      print('🔄 [PROD] Buscando as categorias oficiais do Aliuai...');
      final snapshot = await firestoreProd.collection('categorias').get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ Nenhuma categoria encontrada em PROD sô!');
        return;
      }

      List<Map<String, dynamic>> categoriasExportadas = [];

      for (var doc in snapshot.docs) {
        final dados = doc.data();
        // 🔥 Salvamos o ID do documento para manter o mesmo ID/Slug em DEV sô!
        dados['id_documento_original'] = doc.id;
        categoriasExportadas.add(dados);
      }

      print('\\n---------------- 👇 COPIE O JSON INTEIRO ABAIXO sô! ----------------\\n');
      print(jsonEncode(categoriasExportadas));
      print('\\n--------------------------------------------------------------------\\n');
      print('🚀 [SUCESSO] Dados extraídos! Copie a linha de texto acima.');
    } catch (e) {
      print('❌ Erro ao ler dados de produção sô: $e');
    }
  }

  // ===========================================================================
  // 2º PASSO: RODE EM DEV (Para injetar o JSON que você copiou sô!)
  // ===========================================================================
  static Future<void> importarJsonParaDev(String jsonRaw) async {
    final firestoreDev = FirebaseFirestore.instance;
    final batch = firestoreDev.batch();

    try {
      print('🔄 [DEV] Iniciando o processo de injeção via Batch...');
      final List<dynamic> listaDados = jsonDecode(jsonRaw);

      for (var item in listaDados) {
        final Map<String, dynamic> dados = Map<String, dynamic>.from(item);

        // Recupera o ID amigável original e remove do mapa para não sujar o documento sô
        final String idDoc = dados['id_documento_original'];
        dados.remove('id_documento_original');

        final docRef = firestoreDev.collection('categorias').doc(idDoc);
        batch.set(docRef, dados);
      }

      await batch.commit();
      print('🚀 [SUCESSO BRUTO] A coleção "categorias" foi clonada em DEV com sucesso sô!');
    } catch (e) {
      print('❌ Erro ao salvar dados em DEV sô: $e');
    }
  }
}

class MigradorSecoesCardapio {
  // ===========================================================================
  // 1º PASSO: RODE EM PROD (Para extrair o JSON das seções do cardápio sô!)
  // ===========================================================================
  static Future<void> exportarCategoriaProdutoDeProdParaJson() async {
    final firestoreProd = FirebaseFirestore.instance;

    try {
      print('🔄 [PROD] Buscando as seções de produtos oficiais (categoria_produto)...');
      final snapshot = await firestoreProd.collection('categoria_produto').get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ Nenhuma seção encontrada em categoria_produto lá em PROD sô!');
        return;
      }

      List<Map<String, dynamic>> secoesExportadas = [];

      for (var doc in snapshot.docs) {
        final dados = doc.data();
        // 🔥 Garante que vamos manter o mesmo ID/Slug (ex: 'burgers', 'pizzas') em DEV sô!
        dados['id_documento_original'] = doc.id;
        secoesExportadas.add(dados);
      }

      print('\\n---------------- 👇 COPIE O JSON INTEIRO DE PRODUTOS ABAIXO sô! ----------------\\n');
      print(jsonEncode(secoesExportadas));
      print('\\n--------------------------------------------------------------------------------\\n');
      print('🚀 [SUCESSO] Seções extraídas! Copie a linha de texto acima sô.');
    } catch (e) {
      print('❌ Erro ao ler categoria_produto de produção sô: $e');
    }
  }

  // ===========================================================================
  // 2º PASSO: RODE EM DEV (Para injetar o JSON das seções do cardápio sô!)
  // ===========================================================================
  static Future<void> importarCategoriaProdutoParaDev(String jsonRaw) async {
    final firestoreDev = FirebaseFirestore.instance;
    final batch = firestoreDev.batch();

    try {
      print('🔄 [DEV] Iniciando a injeção de categoria_produto via Batch...');
      final List<dynamic> listaDados = jsonDecode(jsonRaw);

      for (var item in listaDados) {
        final Map<String, dynamic> dados = Map<String, dynamic>.from(item);

        // Puxa o ID original e limpa o mapa
        final String idDoc = dados['id_documento_original'];
        dados.remove('id_documento_original');

        final docRef = firestoreDev.collection('categoria_produto').doc(idDoc);
        batch.set(docRef, dados);
      }

      await batch.commit();
      print('🚀 [SUCESSO BRUTO] A coleção "categoria_produto" foi clonada em DEV com sucesso sô!');
    } catch (e) {
      print('❌ Erro ao salvar categoria_produto em DEV sô: $e');
    }
  }
}
