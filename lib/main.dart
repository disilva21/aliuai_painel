import 'package:aliuai_painel/home_screen.dart';
import 'package:aliuai_painel/termos_uso_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 IMPORTAÇÃO DO FIRESTORE PRA FAZER A VIGIA SÔ!

import 'login_screen.dart';
import 'admin/admin_login_screen.dart';
import 'admin/admin_home_screen.dart';
import 'manutencao_screen.dart'; // 🚜 IMPORTA A TELA DE MANUTENÇÃO QUE CRIAMOS SÔ!

void runInEnvironment() {
  runApp(const AliuaiPainelApp());
}

class AliuaiPainelApp extends StatelessWidget {
  const AliuaiPainelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🚀 MANTEMOS O MATERIALAPP FIXO NA RAIZ SÔ!
    final double larguraTela = MediaQuery.of(context).size.width;

    return MaterialApp(
      title: 'Painel do Parceiro | Aliuai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange, primaryColor: const Color(0xFFE65100), scaffoldBackgroundColor: const Color(0xFFF5F5F5), fontFamily: 'Roboto'),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin': (context) => const AdminLoginScreen(),
        '/home': (context) => const HomeScreen(lojaId: null),
        '/admin/home': (context) => const AdminHomeScreen(),
        '/termos': (context) => const TermosUsoPage(),
      },

      // 🛰️ O PULO DO GATO SENIOR: O 'builder' intercepta a tela que vai ser exibida!
      builder: (context, child) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('configuracao').doc('ziNL1wNtBbGRWSQHCRzQ').snapshots(),
          builder: (streamContext, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return child ??
                  const Scaffold(
                    body: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))),
                  );
            }

            final dadosConfig = snapshot.data!.data() as Map<String, dynamic>?;

            final bool emManutencao = dadosConfig?['manutencao_sistema'] ?? false;
            final bool mostrarAviso = dadosConfig?['manutencao_aviso'] ?? false;
            final String tempoRestante = dadosConfig?['manutencao_tempo'] ?? 'em breve';
            final String whatsappAdmin = dadosConfig?['whatsapp_admin'];

            // 🚨 1. SE ESTIVER EM MANUTENÇÃO GERAL: Tranca o trator na oficina sô!
            if (emManutencao) {
              return ManutencaoScreen(whatsappAdmin: whatsappAdmin);
            }

            // ⚠️ 2. SE FOR APENAS AVISO PRÉVIO: Injeta a barra de alerta no topo sô!
            if (mostrarAviso && child != null) {
              return Scaffold(
                body: Column(
                  children: [
                    // 🚧 A BARRA DE ALERTA BRUTA SÔ!
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFFFB74D), width: 1.5)),
                        color: Color(0xFFFFF3E0), // Fundo laranja clarinho
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center, // Alinha o ícone no meio vertical sô
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 22),
                          const SizedBox(width: 10),

                          // 🚀 O PULO DO GATO PRO MOBILE: O Expanded força o texto a respeitar os limites da tela sô!
                          Expanded(
                            child: RichText(
                              textAlign: larguraTela < 600 ? TextAlign.center : TextAlign.center, // No celular alinha na esquerda pra ler melhor sô!
                              text: TextSpan(
                                style: const TextStyle(color: Color(0xFFE65100), fontSize: 13, height: 1.3), // Altura de linha boa pro mobile sô
                                children: [
                                  const TextSpan(
                                    text: 'Aviso do Aliuai sô! \n',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  TextSpan(
                                    text: tempoRestante, // 🕒 Puxa do seu Firebase sô!
                                    style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // O resto do aplicativo roda normal aqui para baixo sô!
                    Expanded(child: child),
                  ],
                ),
              );
            }

            // ✅ 3. FLUXO NORMAL: Sem aviso e sem manutenção sô!
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
