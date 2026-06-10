// import 'dart:io';
import 'dart:typed_data';
// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:image_picker/image_picker.dart'; // 🔴 Import do Cortador de Imagem
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class CadastroEventoPage extends StatefulWidget {
  final String lojaId;
  final String? eventoId;

  const CadastroEventoPage({super.key, required this.lojaId, this.eventoId});

  @override
  State<CadastroEventoPage> createState() => _CadastroEventoEstabelecimentoPageState();
}

class _CadastroEventoEstabelecimentoPageState extends State<CadastroEventoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;
  bool _subindoImagem = false; // Controle do progresso do banner
  final ImagePicker _picker = ImagePicker();

  // Controladores dos Inputs
  final _tituloController = TextEditingController();

  final HtmlEditorController _descricaoController = HtmlEditorController();
  final _enderecoController = TextEditingController();
  String _descricaoInicial = '';

  // Datas de Controle
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool carregandoDadosEdicao = false;
  String _statusSelecionado = 'Ativo';
  String? _urlBannerEvento;

  @override
  void initState() {
    super.initState();
    // 🔴 Se veio um ID de evento, busca os dados do banco para editar
    if (widget.eventoId != null) {
      _carregarDadosDoEvento();
    }
  }

  // 🔄 Função para buscar os dados antigos do Firestore
  Future<void> _carregarDadosDoEvento() async {
    setState(() => carregandoDadosEdicao = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('eventos').doc(widget.eventoId).get();

      if (doc.exists) {
        final dados = doc.data() as Map<String, dynamic>;
        setState(() {
          _tituloController.text = dados['titulo'] ?? '';
          _statusSelecionado = dados['status'] == true ? 'Ativo' : 'Inativo';
          _enderecoController.text = dados['endereco'] ?? '';
          _urlBannerEvento = dados['banner'].toString().isNotEmpty ? dados['banner'] : null;

          _dataInicio = (dados['data_inicio'] as Timestamp).toDate();
          _dataFim = (dados['data_fim'] as Timestamp).toDate();

          _descricaoInicial = dados['descricao'] ?? '';
        });

        // Injeta o texto HTML para dentro do editor rico
        _descricaoController.setText(_descricaoInicial);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar dados para edição: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => carregandoDadosEdicao = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.clear();
    _enderecoController.dispose();
    super.dispose();
  }

  // 📸 FUNÇÃO 1: Seleciona, Recorta e Envia o Banner para o Firebase Storage
  Future<void> _selecionarRecortarESubirBanner() async {
    try {
      // 1. O lojista escolhe a imagem no computador (Web)
      final XFile? imagemSelecionada = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Mantém uma qualidade boa para Web
      );

      if (imagemSelecionada == null) return;

      // 2. FORÇA O PREVIEW LOCAL INSTANTÂNEO NA TELA (Garante que o lojista veja a foto na hora)
      setState(() {
        _subindoImagem = true;
        // Atribuímos temporariamente o caminho local para o Flutter Web desenhar o preview
        _urlBannerEvento = imagemSelecionada.path;
      });

      // 3. Prepara o caminho no Firebase Storage
      String nomeArquivo = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference refStorage = FirebaseStorage.instance.ref().child('estabelecimentos').child(widget.lojaId).child('eventos').child(nomeArquivo);

      // 4. LÊ OS BYTES DA IMAGEM (Obrigatório para Flutter Web)
      Uint8List bytesImagem = await imagemSelecionada.readAsBytes();

      // 5. Envia os dados e aguarda a conclusão
      UploadTask uploadTask = refStorage.putData(bytesImagem, SettableMetadata(contentType: 'image/jpeg'));

      // Aguarda o upload terminar de fato
      TaskSnapshot snapshot = await uploadTask;

      // 6. PEGA A URL PÚBLICA DEFINITIVA
      String urlPublica = await snapshot.ref.getDownloadURL();

      // 7. ATUALIZA O ESTADO COM A URL FINAL DO FIREBASE
      setState(() {
        _urlBannerEvento = urlPublica; // Substitui o caminho local pela URL real da nuvem
        _subindoImagem = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banner processado e ativo no painel!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() {
        _subindoImagem = false;
        _urlBannerEvento = null; // Limpa se der erro para não mostrar preview quebrado
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao processar imagem na Web: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _selecionarDataHora(BuildContext context, bool isInicio) async {
    // 1. Remove totalmente o foco e fecha qualquer teclado/extensão da Web
    FocusScope.of(context).unfocus();

    final agora = DateTime.now();
    final hojeApenasData = DateTime(agora.year, agora.month, agora.day);

    // 2. Usamos um truque de renderização: forçamos um micro-atraso para o navegador
    // processar que o teclado fechou antes de desenhar o calendário na tela.
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: hojeApenasData,
      firstDate: hojeApenasData.subtract(const Duration(days: 1)),
      lastDate: hojeApenasData.add(const Duration(days: 365)),
      confirmText: 'AVANÇAR',
      cancelText: 'CANCELAR',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        // 🔴 O SEGREDO DO SUCESSO: Envelopamos o calendário no PointerInterceptor
        // Isso impede que o IFrame do HtmlEditor "engula" os cliques dos botões.
        return PointerInterceptor(
          intercepting: true, // Força a Web a priorizar os cliques nesta janela
          child: Theme(
            data: Theme.of(context).copyWith(
              visualDensity: VisualDensity.standard,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFE65100), // Laranja Aliuai
                onPrimary: Colors.white,
                surface: Color(0xFF2D2D3A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (dataSelecionada != null) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));

      final TimeOfDay? horaSelecionada = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        confirmText: 'OK',
        cancelText: 'CANCELAR',
        initialEntryMode: TimePickerEntryMode.dialOnly,
        builder: (context, child) {
          return PointerInterceptor(intercepting: true, child: child!);
        },
      );

      if (horaSelecionada != null) {
        setState(() {
          final dataCompleta = DateTime(dataSelecionada.year, dataSelecionada.month, dataSelecionada.day, horaSelecionada.hour, horaSelecionada.minute);

          if (isInicio) {
            _dataInicio = dataCompleta;
          } else {
            _dataFim = dataCompleta;
          }
        });
      }
    }
  }

  // 💾 FUNÇÃO 3: Gravação final no Firestore
  Future<void> _salvarEvento() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dataInicio == null || _dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defina as datas de início e fim, sô!'), backgroundColor: Colors.amber));
      return;
    }

    if (_dataFim!.isBefore(_dataInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A data de fim não pode ser antes do início!'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _salvando = true);

    try {
      final docLoja = await FirebaseFirestore.instance.collection('estabelecimentos').doc(widget.lojaId).get();

      String cidadeIdDaLoja = '';
      String nomeEstabelecimento = '';
      String logoEstabelecimento = '';

      if (docLoja.exists) {
        final dadosLoja = docLoja.data();

        cidadeIdDaLoja = dadosLoja?['cidade_id'] ?? ''; // 🔥 Puxa o ID salvo no perfil da loja
        nomeEstabelecimento = dadosLoja?['nome'] ?? '';
        logoEstabelecimento = dadosLoja?['logo_url'] ?? '';
      }

      String? htmlGerado = await _descricaoController.getText();
      final dadosEvento = {
        'titulo': _tituloController.text.trim(),
        'descricao': htmlGerado,
        'data_inicio': Timestamp.fromDate(_dataInicio!),
        'data_fim': Timestamp.fromDate(_dataFim!),
        'status': _statusSelecionado == 'Ativo' ? true : false,
        'banner': _urlBannerEvento ?? '',
        'cidade_id': cidadeIdDaLoja,
        'estabelecimentoId': widget.lojaId,
        'endereco': _enderecoController.text.trim(),
        'criado_em': FieldValue.serverTimestamp(),
        'estabelecimento_nome': nomeEstabelecimento,
        'estabelecimento_logo': logoEstabelecimento,
      };
      if (widget.eventoId != null) {
        // 🔴 Modo Edição: Atualiza o documento existente
        await FirebaseFirestore.instance.collection('eventos').doc(widget.eventoId).update(dadosEvento);
      } else {
        // 🟢 Modo Cadastro: Cria um novo
        await FirebaseFirestore.instance.collection('eventos').add(dadosEvento);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento cadastrado com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar evento: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info da Cidade
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(16),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF2D2D3A),
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(color: const Color(0xFFE65100).withOpacity(0.3)),
              //   ),
              //   child: Row(
              //     children: [
              //       const Icon(Icons.location_on, color: Color(0xFFE65100)),
              //       const SizedBox(width: 12),
              //       Text(
              //         'Publicando em: ${widget.lojaId}',
              //         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              //       ),
              //     ],
              //   ),
              // ),
              const SizedBox(height: 24),
              Text('Faça o download do seu banner para esse evento!', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 10),
              // 🖼️ Componente do Banner com Loader
              GestureDetector(
                onTap: _subindoImagem ? null : _selecionarRecortarESubirBanner,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    // color: const Color(0xFF2D2D3A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _urlBannerEvento != null ? const Color(0xFFE65100) : Colors.grey[700]!, width: _urlBannerEvento != null ? 2 : 1),
                    // 🔴 Renderiza a imagem perfeitamente na Web usando NetworkImage
                    image: _urlBannerEvento != null
                        ? DecorationImage(
                            image: NetworkImage(_urlBannerEvento!),
                            fit: BoxFit.cover,
                            alignment: Alignment.center, // Corta as rebarbas automaticamente no formato do container
                          )
                        : null,
                  ),
                  child: _subindoImagem
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFFE65100)),
                              SizedBox(height: 12),
                              Text('Enviando banner para o servidor...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        )
                      : _urlBannerEvento == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Clique para selecionar o Banner do Evento', style: TextStyle(color: Colors.grey)),
                            Text('(Recomendado: Proporção 16:9 ou 1280x720px)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        )
                      : const SizedBox.shrink(), // Oculta o texto quando a imagem carrega
                ),
              ),
              const SizedBox(height: 24),

              _construirInput(controller: _tituloController, label: 'Título do Evento (Ex: Rodízio de Pizza com Música ao Vivo)'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _construirSeletorData(titulo: 'Início do Evento', data: _dataInicio, formatador: dateFormat, onTap: () => _selecionarDataHora(context, true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _construirSeletorData(titulo: 'Fim do Evento', data: _dataFim, formatador: dateFormat, onTap: () => _selecionarDataHora(context, false)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _construirInput(controller: _enderecoController, label: 'Endereço do Evento (Ex: Av. Principal, 150 - Centro ou "No próprio estabelecimento")'),

              const SizedBox(height: 24),

              // Status
              DropdownButtonFormField<String>(
                value: _statusSelecionado,

                decoration: const InputDecoration(labelText: 'Status do Evento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city_rounded)),

                items: const [
                  DropdownMenuItem(value: 'Ativo', child: Text('Ativo (Disponível no App)')),
                  DropdownMenuItem(value: 'Inativo', child: Text('Inativo (Escondido)')),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _statusSelecionado = valor);
                },
              ),
              const SizedBox(height: 20),
              Text('* Utilize o campo abaixo para informar o que vai rolar no evento!', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HtmlEditor(
                  controller: _descricaoController,
                  htmlEditorOptions: HtmlEditorOptions(
                    hint: "Ex: <b>Festa de inauguração:</b> nesse sábado...",
                    initialText: _descricaoInicial, // Injeta o texto do Firestore
                    shouldEnsureVisible: true,
                    autoAdjustHeight: true,
                  ),
                  htmlToolbarOptions: HtmlToolbarOptions(
                    toolbarPosition: ToolbarPosition.aboveEditor, // Barra fixa no topo
                    toolbarType: ToolbarType.nativeScrollable, // Rolagem suave dos botões
                    // Lista limpa e atualizada de ferramentas para o lojista usar
                    defaultToolbarButtons: [
                      const FontSettingButtons(fontSize: true), // Tamanho da letra
                      const FontButtons(bold: true, italic: true, underline: true, clearAll: true), // Formatações básicas
                      const ColorButtons(foregroundColor: true), // Cores do texto
                      const ListButtons(ul: true, ol: true), // Marcadores de listas (ótimo para horários)
                      const ParagraphButtons(alignLeft: true, alignCenter: true, alignRight: true),
                    ],
                  ),

                  // Outras opções de tamanho do container interno
                  otherOptions: const OtherOptions(height: 200),
                ),
              ),

              const SizedBox(height: 40),
              // Botão de Envio
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                  onPressed: _salvando ? null : _salvarEvento,
                  child: _salvando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Publicar Evento sô!',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirInput({required TextEditingController controller, required String label, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      // style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE65100))),
        // filled: true,
        // fillColor: const Color(0xFF2D2D3A),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Faltou preencher esse campo!' : null,
    );
  }

  Widget _construirSeletorData({required String titulo, required DateTime? data, required DateFormat formatador, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          // color: const Color(0xFF2D2D3A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data != null ? formatador.format(data) : 'Definir data',
                    style: TextStyle(color: data != null ? Colors.black : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
