import 'package:connect_sports/provider/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connect_sports/screens/navigation.dart';
import 'package:connect_sports/screens/usuario/login.dart';
import 'package:connect_sports/screens/splash/splash_screen.dart';
import 'package:connect_sports/screens/home/home_screen.dart';
import 'provider/theme_provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(
    fileName: "assets/.env",
  );

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  String? appID = dotenv.env['ONESIGNAL_APP_ID'];

  OneSignal.initialize( appID ?? "APP_ID");
  OneSignal.Notifications.requestPermission(true);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Connect Sports',
      //theme: ThemeData(primarySwatch: Colors.blue),
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      initialRoute: '/', // Define a rota inicial
      routes: {
        '/': (context) => SplashScreen(), // Tela inicial (Splash)
        '/login': (context) => LoginScreen(), // Tela de login
        '/home': (context) => const NavigationConnect(), // Tela principal com navegação
      },
      debugShowCheckedModeBanner: false,
    );
  }
}