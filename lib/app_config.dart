enum AppEnvironment { dev, prod }

class AppConfig {
  final AppEnvironment environment;
  final String appTitle;
  final Map<String, dynamic> firebaseOptions; // Chaves do Firebase do ambiente

  AppConfig({required this.environment, required this.appTitle, required this.firebaseOptions});

  // 🔥 Variável global para acessarmos a configuração de qualquer lugar do app sô!
  static late AppConfig shared;
}
