import 'package:aliuai_painel/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Gerado automaticamente pelo 'flutterfire configure'
import 'login_screen.dart';
import 'admin/admin_login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AliuaiPainelApp());
}

class AliuaiPainelApp extends StatelessWidget {
  const AliuaiPainelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel do Parceiro | AliUai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        primaryColor: const Color(0xFFE65100),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Fundo cinza claro estilo dashboard
      ),
      initialRoute: '/',
      // 4. MAPEIE OS CAMINHOS DA URL DO NAVEGADOR
      routes: {
        // Rota Raiz: Onde o lojista comum entra (Ex: localhost:62983/)
        '/': (context) => const LoginScreen(), // Substitua pela sua tela de login do lojista
        // Rota Admin: Onde VOCÊ entra (Ex: localhost:62983/admin)
        '/admin': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        // Rota Dashboard Admin: Para navegação interna após o login
        '/admin/dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}
