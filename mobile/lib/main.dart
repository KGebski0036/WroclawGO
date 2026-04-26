import 'package:flutter/material.dart';

import 'core/storage/token_storage.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'services/attraction_service.dart';
import 'services/auth_service.dart';
import 'state/app_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobileApp());
}

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  late final AppSession _session;
  final AttractionService _attractionService = AttractionService();

  @override
  void initState() {
    super.initState();
    _session = AppSession(
      authService: AuthService(),
      tokenStorage: TokenStorage(),
    )..initialize();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'WroclawGO',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F5D8C),
            ),
            useMaterial3: true,
          ),
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_session.isAuthenticated) {
      return LoginScreen(session: _session);
    }

    return MapScreen(session: _session, attractionService: _attractionService);
  }
}
