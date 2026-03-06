import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // İlk açılışta tüm izinleri iste
  await _requestPermissions();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Platform channel ile native taraftan iste
  const platform = MethodChannel('com.secureshare/native');
  try {
    await platform.invokeMethod('requestAllPermissions');
  } catch (e) {
    print('İzin hatası: $e');
  }
  
  // Depolama izni özel kontrol (Android 11+)
  if (await Permission.manageExternalStorage.isDenied) {
    await platform.invokeMethod('openStorageSettings');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.storage,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      title: 'SecureShare',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      primaryColor: const Color(0xFF6C63FF),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F0FF),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF6C63FF),
        onPrimary: Colors.white,
        secondary: const Color(0xFF06D6A0),
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: isDark ? const Color(0xFF1E1E35) : Colors.white,
        onSurface: isDark ? Colors.white : const Color(0xFF1A1A2E),
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
    );
  }
}
