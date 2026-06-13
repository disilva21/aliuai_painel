class FormatarTelefone {
  static String formatarTelefone(String telefone) {
    // Remove tudo o que não for número sô
    String apenasNumeros = telefone.replaceAll(RegExp(r'[^0-9]'), '');

    // Se o caboclo salvou com o 55 do Brasil na frente, a gente arranca só para formatar limpo sô
    if (apenasNumeros.length > 11 && apenasNumeros.startsWith('55')) {
      apenasNumeros = apenasNumeros.substring(2);
    }

    // Celular com 9 dígitos: 31988887777 -> (31) 98888-7777
    if (apenasNumeros.length == 11) {
      return '(${apenasNumeros.substring(0, 2)}) ${apenasNumeros.substring(2, 3)} ${apenasNumeros.substring(3, 7)}-${apenasNumeros.substring(7)}';
    }

    // Telefone Fixo ou antigo com 8 dígitos: 3133334444 -> (31) 3333-4444
    if (apenasNumeros.length == 10) {
      return '(${apenasNumeros.substring(0, 2)}) ${apenasNumeros.substring(2, 6)}-${apenasNumeros.substring(6)}';
    }

    // Se o número estiver incompleto ou bagunçado, devolve o original pro Flutter não quebrar sô!
    return telefone;
  }
}
