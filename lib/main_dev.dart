import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'main.dart' as common_main; // Aponta para o seu app original sô!
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🛠️ Configura o ambiente de Desenvolvimento sô!
  AppConfig.shared = AppConfig(
    environment: AppEnvironment.dev,
    appTitle: '[DEV] Aliuai Painel',
    firebaseOptions: {
      // Injete aqui as chaves do seu Firebase de DEV sô!
      "apiKey": "AIzaSyDYBUWvkixPgQYEKG5nepMRFhC8CcWUJlk",
      "authDomain": "aliuai-dev.firebaseapp.com",
      "projectId": "aliuai-dev",
      "storageBucket": "aliuai-dev.firebasestorage.app",
      "messagingSenderId": "298606995860",
      "appId": "1:298606995860:web:6ec1bf52d10cb8c5c64781",
    },
  );

  // Inicializa o Firebase passando as opções dinâmicas do Flavor sô!
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: AppConfig.shared.firebaseOptions['apiKey'],
      authDomain: AppConfig.shared.firebaseOptions['authDomain'],
      projectId: AppConfig.shared.firebaseOptions['projectId'],
      storageBucket: AppConfig.shared.firebaseOptions['storageBucket'],
      messagingSenderId: AppConfig.shared.firebaseOptions['messagingSenderId'],
      appId: AppConfig.shared.firebaseOptions['appId'],
    ),
  );

  usePathUrlStrategy();

  // Manda rodar o aplicativo normal sô!
  common_main.runInEnvironment();
}
