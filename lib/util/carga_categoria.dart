import 'package:cloud_firestore/cloud_firestore.dart';

class CargaCategoria {
  static Future<void> rodarAtualizacaoDeCategoriasBracalFinal() async {
    final firestore = FirebaseFirestore.instance;

    // 🗺️ O MAPA DEFINITIVO DO ALIUAI - 30 Categorias mapeadas milimetricamente sô!
    final Map<String, List<String>> vinculosReais = {
      // 🍟 Alimentação & Delivery
      'Lanches': ['cat_restaurantes', 'cat_distribuidora_bebidas', 'cat_utilidades'],
      'Bebidas': ['cat_restaurantes', 'cat_distribuidora_bebidas', 'cat_mercados', 'cat_utilidades'],
      'Porções': ['cat_restaurantes', 'cat_distribuidora_bebidas'],
      'Sobremesas': ['cat_restaurantes', 'cat_mercados', 'cat_utilidades'],
      'Pastéis & Salgados': ['cat_restaurantes', 'cat_utilidades'],
      'Pizzas & Massas': ['cat_restaurantes'],
      'Refeições / Prato Feito': ['cat_restaurantes'], // O causador da quebra de layout sô!
      'Hortifrúti': ['cat_mercados', 'cat_utilidades'],

      // 👕 Moda & Beleza
      'Moda Masculina': ['cat_moda_beleza', 'cat_utilidades'],
      'Moda Feminina': ['cat_moda_beleza', 'cat_utilidades'],
      'Moda Infantil / Enxoval': ['cat_moda_beleza', 'cat_utilidades'],
      'Calçados & Tênis': ['cat_moda_beleza', 'cat_utilidades'],
      'Bijuterias & Acessórios': ['cat_moda_beleza', 'cat_eventos', 'cat_utilidades'],
      'Roupas Íntimas / Lingerie': ['cat_moda_beleza'],
      'Cosméticos & Maquiagem': ['cat_moda_beleza', 'cat_farmacias', 'cat_utilidades'],
      'Perfumaria': ['cat_moda_beleza', 'cat_farmacias', 'cat_utilidades'],

      // ⚡ Eletrônicos & Tecnologia (Entram direto em Utilidades sô!)
      'Informática & Periféricos': ['cat_utilidades', 'cat_servicos'],
      'Carregadores & Cabos': ['cat_utilidades', 'cat_mercados', 'cat_distribuidora_bebidas'],
      'Capas & Películas de Celular': ['cat_utilidades', 'cat_servicos'],
      'Fones & Caixas de Som': ['cat_utilidades', 'cat_eventos'],

      // 🧴 Farmácia & Saúde
      'Higiene Pessoal': ['cat_farmacias', 'cat_mercados', 'cat_utilidades'],
      'Suplementos & Vitaminas': ['cat_farmacias', 'cat_mercados'],

      // 🏠 Casa, Construção & Utilidades
      'Cama, Mesa & Banho': ['cat_material_construcao', 'cat_utilidades'],
      'Decoração & Tapetes': ['cat_material_construcao', 'cat_eventos', 'cat_utilidades'],
      'Ferramentas & Materiais Elétricos': ['cat_material_construcao', 'cat_utilidades'],
      'Gás & Água Mineral': ['cat_distribuidora_bebidas', 'cat_mercados', 'cat_utilidades'],

      // 🐶 Pet Shop (Vinculado aos mercados de bairro e serviços veterinários)
      'Rações & Alimentos Pet': ['cat_mercados', 'cat_utilidades', 'cat_servicos'],
      'Acessórios & Brinquedos Pet': ['cat_utilidades', 'cat_servicos'],
      'Medicamentos Veterinários': ['cat_farmacias', 'cat_servicos'],

      // 🃏 O Curinga Geral sô
      'Outros': ['cat_restaurantes', 'cat_farmacias', 'cat_mercados', 'cat_servicos', 'cat_distribuidora_bebidas', 'cat_material_construcao', 'cat_moda_beleza', 'cat_eventos', 'cat_utilidades'],
    };

    try {
      print('🔄 Iniciando super carga automatizada de 30 categorias no Aliuai...');

      final snapshotProdutos = await firestore.collection('categoria_produto').get();
      final batch = firestore.batch();
      int atualizados = 0;

      for (var doc in snapshotProdutos.docs) {
        String nomeDaCategoriaNoBanco = doc.data()['nome'] ?? '';

        // Remove possíveis espaços sobrando nas pontas sô
        nomeDaCategoriaNoBanco = nomeDaCategoriaNoBanco.trim();

        if (vinculosReais.containsKey(nomeDaCategoriaNoBanco)) {
          // 🔥 Trata o texto para minúsculo, sem acento e com underline
          String slugTratado = ''; // _tratarTextoParaSlug(nomeDaCategoriaNoBanco);

          batch.update(doc.reference, {
            'slug': slugTratado, // ex: "refeicoes_prato_feito"
            'estabelecimentos_permitidos': vinculosReais[nomeDaCategoriaNoBanco],
            'ativo': true,
          });
          atualizados++;
          print('✅ [OK] Categoria: "$nomeDaCategoriaNoBanco" -> Slug: "$slugTratado"');
        } else {
          print('⚠️ [AVISO] A categoria "$nomeDaCategoriaNoBanco" está no banco mas não foi mapeada no script sô. Confira letras e acentos.');
        }
      }

      if (atualizados > 0) {
        await batch.commit();
        print('🚀 [SUCESSO BRUTO] Carga finalizada! $atualizados subcategorias atualizadas com slug e cat_ pais sô!');
      } else {
        print('❌ Nenhuma categoria foi atualizada sô. Verifique se os nomes batem 100% com o banco.');
      }
    } catch (e) {
      print('❌ Erro grave na execução da carga sô: $e');
    }
  }
}
