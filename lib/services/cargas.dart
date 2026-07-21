// 🎯 FUNÇÃO TEMPORÁRIA PARA CARGA DE CATEGORIAS NO FIRESTORE
import 'package:cloud_firestore/cloud_firestore.dart';

class CargaDeCategorias {
  static Future<void> fazerCargaDeCategorias() async {
    final CollectionReference categoriasRef = FirebaseFirestore.instance.collection('categorias');

    // 🌾 Lista com a fiação das novas categorias organizada
    final List<Map<String, dynamic>> novasCategorias = [
      {
        'nome': 'Mercados',
        'cor': '#2E7D32', // Verde mercado sô!
        'icone': '58261', // Icons.local_grocery_store (Código decimal: 58261 / Hex: e395)
        'ordem': 1,
        'ativo': true,
      },
      {
        'nome': 'Distribuidoras',
        'cor': '#E65100', // Laranja escuro / Bebidas
        'icone': '58252', // Icons.local_bar (Código decimal: 58252 / Hex: e38c)
        'ordem': 2,
        'ativo': true,
      },
      {
        'nome': 'Cultura',
        'cor': '#6D4C41', // Marrom histórico
        'icone': '59471', // Icons.account_balance (Patrimônio/Museu / Código: 59471)
        'ordem': 3,
        'ativo': true,
      },
      {
        'nome': 'Religiao',
        'cor': '#00897B', // Azul turquesa / Fé
        'icone':
            '58134', // Icons.church (Convertido para classic/ecumênico / Icons.home_work ou Icons.church se suportar, usaremos 58134 para Icons.favorite / amor ou 59471. Vamos de 40990 para Icons.home_work que funciona 100%)
        'ordem': 4,
        'ativo': true,
      },
      {
        'nome': 'Eventos',
        'cor': '#D81B60', // Rosa pink festivo
        'icone': '57918', // Icons.event (Código decimal: 57918 / Hex: e23e)
        'ordem': 50,
        'ativo': true,
      },
      {
        'nome': 'Farmacias',
        'cor': '#E53935', // Vermelho clássico de saúde
        'icone': '58270', // Icons.local_pharmacy (Código decimal: 58270 / Hex: e39e)
        'ordem': 6,
        'ativo': true,
      },
      {
        'nome': 'Veterinaria',
        'cor': '#00ACC1', // Ciano clínicas
        'icone': '58262', // Icons.local_hospital (Cruz de clínica veterinária / Código: 58262)
        'ordem': 7,
        'ativo': true,
      },
      {
        'nome': 'Construcao',
        'cor': '#D84315', // Laranja tijolo/ferragens
        'icone': '58051', // Icons.build (Chave inglesa clássica / Código: 58051 / Hex: e116)
        'ordem': 8,
        'ativo': true,
      },
      {
        'nome': 'Agropecuaria',
        'cor': '#558B2F', // Verde folha / Agro
        'icone': '58259', // Icons.local_florist (Representa sementes e plantas / Código: 58259)
        'ordem': 9,
        'ativo': true,
      },
      {
        'nome': 'Artesanato',
        'cor': '#8D6E63', // Marrom argila / Feito à mão
        'icone': '57619', // Icons.brush (Pincel / Código: 57619 / Hex: e113)
        'ordem': 10,
        'ativo': true,
      },
      {
        'nome': 'Presentes',
        'cor': '#8E24AA', // Roxo presentes
        'icone': '57662', // Icons.card_giftcard (Caixinha de presente / Código: 57662 / Hex: e13e)
        'ordem': 11,
        'ativo': true,
      },
      {
        'nome': 'Vestuario',
        'cor': '#FF4081', // Rosa boutique
        'icone': '60205', // Icons.checkroom (Cabide clássico / Código: 60205)
        'ordem': 12,
        'ativo': true,
      },
      {
        'nome': 'Beleza',
        'cor': '#F06292', // Rosa suave / Salões
        'icone': '58176', // Icons.face (Rosto / Código: 58176)
        'ordem': 13,
        'ativo': true,
      },
      {
        'nome': 'Academia',
        'cor': '#3949AB', // Azul escuro / Energia
        'icone': '57997', // Icons.fitness_center (Halteres / Código: 57997 / Hex: e28d)
        'ordem': 14,
        'ativo': true,
      },
      {
        'nome': 'Perfumaria',
        'cor': '#BA68C8', // Lilás / Essências
        'icone': '58259', // Icons.local_florist (Flor / Código: 58259)
        'ordem': 15,
        'ativo': true,
      },
      {
        'nome': 'Restaurantes',
        'cor': '#C62828', // Vermelho jantares/refeições
        'icone': '58732', // Icons.restaurant (Garfo e faca / Código: 58732)
        'ordem': 16,
        'ativo': true,
      },
      {
        'nome': 'Lanchonetes',
        'cor': '#FF8F00', // Laranja mostarda/fastfood
        'icone': '58224', // Icons.fastfood (Hambúrguer e refri / Código: 58224)
        'ordem': 17,
        'ativo': true,
      },
      {
        'nome': 'Servicos',
        'cor': '#455A64', // Cinza escuro / Corporativo
        'icone': '57792', // Icons.design_services (Ferramentas de serviço / Código: 57792 / Hex: e1c0)
        'ordem': 18,
        'ativo': true,
      },
      {
        'nome': 'Informatica',
        'cor': '#1565C0', // Azul tecnologia
        'icone': '58444', // Icons.laptop_mac (Computador / Código: 58444)
        'ordem': 19,
        'ativo': true,
      },
      {
        'nome': 'Utilidades',
        'cor': '#FFB300', // Amarelo utilidades para casa
        'icone': '58131', // Icons.home (Casinha / Código: 58131)
        'ordem': 100,
        'ativo': true,
      },
      {
        'nome': 'Laboratorios',
        'cor': '#0288D1', // Azul clínico / Exames
        'icone': '58714', // Icons.science (Tubo de ensaio / Código: 58714 / Hex: e55a)
        'ordem': 21,
        'ativo': true,
      },
    ];

    try {
      print('🚀 Iniciando a carga de categorias no AliUai...');

      for (var cat in novasCategorias) {
        // Criamos um documento com ID personalizado baseado no nome para evitar duplicados
        final String docId = 'cat_${cat['nome'].toString().toLowerCase().replaceAll(' ', '_').replaceAll('&', 'e')}';

        await categoriasRef.doc(docId).set(cat);
        print('✅ Categoria "${cat['nome']}" enviada com sucesso! ID: $docId');
      }

      print('🎉 Carga finalizada com sucesso, uai! Todas as categorias estão no Firestore.');
    } catch (e) {
      print('❌ Erro ao subir as categorias sô: $e');
    }
  }
}
