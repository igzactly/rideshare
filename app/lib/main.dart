import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:rideshare_app/providers/auth_provider.dart';
import 'package:rideshare_app/providers/ride_provider.dart';
import 'package:rideshare_app/providers/location_provider.dart';
import 'package:rideshare_app/screens/splash_screen.dart';
import 'package:rideshare_app/screens/home_screen.dart';
import 'package:rideshare_app/screens/login_screen.dart';
import 'package:rideshare_app/screens/register_screen.dart';
import 'package:rideshare_app/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables with fallback
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Fallback to default values if .env is not found
    print("Warning: .env file not found, using default configuration");
    // Set default values
    dotenv.env['API_BASE_URL'] = 'http://158.158.41.106:8000';
    dotenv.env['APP_NAME'] = 'RideShare';
    dotenv.env['APP_VERSION'] = '1.0.0';
  }

  runApp(const RideShareApp());
}

class RideShareApp extends StatelessWidget {
  const RideShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'RideShare',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            default:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(builder: (_) => const SplashScreen());
        },
      ),
    );
  }
}
