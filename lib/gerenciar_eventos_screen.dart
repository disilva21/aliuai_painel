import 'package:aliuai_painel/cadastro_evento_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// 🔴 Importe a sua tela de cadastro aqui

class GerenciarEventosPage extends StatefulWidget {
  final String lojaId;

  const GerenciarEventosPage({super.key, required this.lojaId});

  @override
  State<GerenciarEventosPage> createState() => _GerenciarEventosPageState();
}

class _GerenciarEventosPageState extends State<GerenciarEventosPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _carregando = true;
  String _planoAtual = 'indefinido';
  String? _nomeEstabelecimento;
  // Função rápida para alternar o status do evento direto da lista (Ativar/Inativar)
  @override
  void initState() {
    _buscarPlanoAtual();
    super.initState();
  }

  Future<void> _alternarStatusEvento(String eventoId, bool statusAtual) async {
    try {
      await FirebaseFirestore.instance.collection('eventos').doc(eventoId).update({'status': statusAtual});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status do evento atualizado para $statusAtual!'), backgroundColor: statusAtual == true ? Colors.green : Colors.grey[700]));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao mudar status: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarAlertaPagamento() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.amber[800], size: 28),
              const SizedBox(width: 12),
              const Text('Escolha seu plano! 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Para cadastrar eventos você precisa contratar um dos nossos planos.', style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Faça contratação de um plano agora mesmo!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // BOTÃO 1: LEVA DIRETO PARA A TELA DE PLANOS DO SEU PAINEL
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context); // Fecha a modal

                // MUDANÇA DE ABA: Se a sua HomeScreen gerencia as abas,
                // você pode disparar um callback ou avisar o lojista para ir até lá.
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Clique na aba "Planos de Assinatura" no menu lateral para escolher seu novo plano! 😉'), backgroundColor: Colors.blue));
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Text(
              '📅 Meus Eventos',
              style: TextStyle(color: Color(0xFF2D2D3A), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D2D3A)),
        automaticallyImplyLeading: false,
        actions: [
          // Botão flutuante no topo para criar um novo evento
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo Evento', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _planoAtual == 'indefinido'
                  ? _mostrarAlertaPagamento
                  : () {
                      // 🟢 Abre a tela para CADASTRAR um novo evento usando a mesma modal lateral
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        isDismissible: false,
                        builder: (context) {
                          return FractionallySizedBox(
                            widthFactor: 0.8,
                            heightFactor: 0.95,
                            alignment: Alignment.centerRight, // Cola no lado direito
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                              child: Scaffold(
                                appBar: AppBar(
                                  backgroundColor: const Color(0xFFF5F5F5),
                                  elevation: 0,
                                  leading: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFF2D2D3A)),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  title: const Text(
                                    'Novo Evento', // Título fixo de cadastro
                                    style: TextStyle(color: Color(0xFF2D2D3A), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                body: CadastroEventoPage(
                                  lojaId: widget.lojaId,
                                  eventoId: null, // 🔴 ATENÇÃO: Passando null aqui força o modo CADASTRO limpo!
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Traz TODOS os eventos deste estabelecimento específico (ativos ou inativos)
        stream: FirebaseFirestore.instance.collection('eventos').where('estabelecimentoId', isEqualTo: widget.lojaId).orderBy('criado_em', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Erro ao carregar dados: ${snapshot.error}');
            return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)));
          }

          final listaEventos = snapshot.data?.docs ?? [];

          if (listaEventos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Você ainda não cadastrou nenhum evento sô!', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 12),
                  // ElevatedButton(
                  //   style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7B1FA2)),
                  //   onPressed: _planoAtual == 'indefinido'
                  //       ? _mostrarAlertaPagamento
                  //       : () {
                  //           Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroEventoPage(lojaId: widget.lojaId)));
                  //         },
                  //   child: const Text('Criar Meu Primeiro Evento', style: TextStyle(color: Colors.white)),
                  // ),
                ],
              ),
            );
          }

          // 💻 LAYOUT EM GRADE (RESPONSIVO PARA WEB)
          // Se a tela for larga (computador), mostra mais colunas; se for menor, mostra menos.
          double larguraTela = MediaQuery.of(context).size.width;
          int colunas = larguraTela > 1200 ? 3 : (larguraTela > 800 ? 2 : 1);

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colunas,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 470, // Altura fixa de cada card para não quebrar o layout
            ),
            itemCount: listaEventos.length,
            itemBuilder: (context, index) {
              final doc = listaEventos[index];
              final dados = doc.data() as Map<String, dynamic>;

              final String id = doc.id;
              final String titulo = dados['titulo'] ?? 'Sem título';
              final String? banner = dados['banner'] != null && dados['banner'].toString().isNotEmpty ? dados['banner'] : null;
              final bool isAtivo = dados['status'] ?? false;

              final DateTime dataInicio = (dados['data_inicio'] as Timestamp).toDate();
              final DateTime dataFim = (dados['data_fim'] as Timestamp).toDate();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🖼️ Imagem do Banner
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: banner != null
                                ? Image.network(banner, fit: BoxFit.cover)
                                : Container(
                                    color: Color(0xFF7B1FA2).withOpacity(0.1),
                                    child: const Icon(Icons.broken_image, color: Color(0xFF7B1FA2)),
                                  ),
                          ),
                        ),
                        // Badge indicador de Status
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: isAtivo ? Colors.green : Colors.grey[700], borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              isAtivo ? 'Ativo' : 'Inativo',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 📝 Informações
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D3A)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('Início: ${dateFormat.format(dataInicio)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text('Término: ${dateFormat.format(dataFim)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          const Divider(height: 24),

                          // ⚙️ Botões de Ação rápidos
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Botão Ativar/Inativar
                              IconButton(
                                tooltip: isAtivo ? 'Inativar (Ocultar no App)' : 'Ativar (Mostrar no App)',
                                icon: Icon(isAtivo ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: isAtivo ? Color(0xFF7B1FA2) : Colors.grey),
                                onPressed: () => _alternarStatusEvento(id, !isAtivo),
                              ),

                              // Botão Editar completo
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D2D3A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Editar', style: TextStyle(fontSize: 13)),
                                onPressed: _planoAtual == 'indefinido'
                                    ? _mostrarAlertaPagamento
                                    : () {
                                        // 🔴 Abre a tela de cadastro/edição deslizando pela lateral ou cobrindo apenas a área do conteúdo
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true, // Permite que a tela ocupe a altura necessária
                                          backgroundColor: Colors.transparent, // Deixa o fundo invisível para usarmos o design da página
                                          builder: (context) {
                                            // Usamos um FractionallySizedBox para fazer ela ocupar 80% da largura da tela na Web,
                                            // deixando o menu lateral esquerdo visível!
                                            return FractionallySizedBox(
                                              widthFactor: 0.8,
                                              heightFactor: 0.95, // Ocupa quase toda a altura, deixando uma bordinha charmosa
                                              alignment: Alignment.centerRight, // Cola o modal no lado direito da tela
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                                                child: Scaffold(
                                                  // Envolvemos num Scaffold próprio para criar uma barra de fechar elegante
                                                  appBar: AppBar(
                                                    backgroundColor: const Color(0xFFF5F5F5),
                                                    elevation: 0,
                                                    leading: IconButton(
                                                      icon: const Icon(Icons.close_rounded, color: Color(0xFF2D2D3A)),
                                                      onPressed: () => Navigator.pop(context), // Botão de fechar o modal
                                                    ),
                                                    title: Text(
                                                      'Novo Evento sô!',
                                                      style: const TextStyle(color: Color(0xFF2D2D3A), fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  body: CadastroEventoPage(
                                                    lojaId: widget.lojaId,
                                                    eventoId: id, // Passa o ID do evento selecionado
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Puxa o plano que está salvo atualmente no banco
  Future<void> _buscarPlanoAtual() async {
    try {
      final docLoja = await _firestore.collection('estabelecimentos').doc(widget.lojaId).get();

      if (docLoja.exists && mounted) {
        setState(() {
          _planoAtual = docLoja.data()?['plano_atual'] ?? 'indefinido';
          _carregando = false;
          _nomeEstabelecimento = docLoja.data()?['nome'] ?? 'Estabelecimento';
        });
      }
    } catch (e) {
      print('Erro ao buscar plano atual: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }
}
