import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_config.dart';
import 'main.dart' as common_main;
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 Configura o ambiente de Produção Real sô!
  AppConfig.shared = AppConfig(
    environment: AppEnvironment.prod,
    appTitle: 'Aliuai Painel Administrativo',
    firebaseOptions: {
      // Injete aqui as chaves do seu Firebase de PROD real!
      "apiKey": "AIzaSyCL0gXy8iuQUqiU87MOWez17sHAtIoMOys",
      "authDomain": "aliuai.firebaseapp.com",
      "projectId": "aliuai",
      "storageBucket": "aliuai.firebasestorage.app",
      "messagingSenderId": "548234965981",
      "appId": "1:548234965981:web:6c0d947e75377bfdda7c34",
    },
  );

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
  common_main.runInEnvironment();
}
