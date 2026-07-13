class Permissoes {
  // O gerente pode tudo
  static bool ehGerente(String? nivel) => nivel == 'gerente';

  // Gerente e Operador mexem em pedidos/caixa
  static bool podeMexerEmPedidos(String? nivel) => nivel == 'gerente' || nivel == 'operador';

  // Gerente e Estoquista mexem em produtos/estoque
  static bool podeGerenciarProdutos(String? nivel) => nivel == 'gerente' || nivel == 'estoquista';

  // Só o gerente vê o financeiro/relatórios
  static bool podeVerFinanceiro(String? nivel) => nivel == 'gerente';
}
