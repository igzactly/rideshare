import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/ride_provider.dart';
import 'utils/theme.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/passenger_dashboard_screen.dart';
import 'screens/my_rides_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications (temporarily disabled)
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  // Load environment variables with fallback
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
    debugPrint('Using default API configuration');
  }

  runApp(const PassengerApp());
}

class PassengerApp extends StatelessWidget {
  const PassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: 'RideShare Passenger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/dashboard': (context) => const PassengerDashboardScreen(),
          '/my-rides': (context) => const MyRidesScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/dashboard':
              return MaterialPageRoute(builder: (_) => const PassengerDashboardScreen());
            case '/my-rides':
              return MaterialPageRoute(builder: (_) => const MyRidesScreen());
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