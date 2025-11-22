import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../../app/config/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _navigationHandled = false;

  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (hasSeenOnboarding) {
        // User lama -> Cek Login
        _setupAuthListener();
      } else {
        // User baru -> Ke ONBOARDING biasa (Intro Cei nanti abis login)
        _navigationHandled = true;
        Navigator.pushReplacementNamed(context, AppRoutes.onboardingRoute);
      }
    } catch (e) {
      _setupAuthListener();
    }
  }

  void _setupAuthListener() {
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted || _navigationHandled) return;

      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
        // Handle manual login event jika trigger dari LoginScreen
          if (session != null) {
            _prepareUserSessionAndNavigate(session);
          }
          break;
          
        case AuthChangeEvent.initialSession:
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_navigationHandled) {
              if (session != null) {
                _prepareUserSessionAndNavigate(session);
              } else {
                _navigationHandled = true;
                Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
              }
            }
          });
          break;
          
        // ... case lainnya (signedOut, etc) tetap sama ...
        case AuthChangeEvent.signedOut:
          _navigationHandled = true;
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.loginRoute, (route) => false);
          break;
        default:
          break;
      }
    });
  }

  // --- INI LOGIKA UTAMANYA ---
  Future<void> _prepareUserSessionAndNavigate(Session session) async {
    if (!mounted) return;
    final userEmail = session.user.email;
    
    if (userEmail != null) {
      try {
        if (!Hive.isBoxOpen('pantry_$userEmail')) {
          await Hive.openBox<String>('pantry_$userEmail');
        }

        if (!_navigationHandled && mounted) {
          _navigationHandled = true;
          
          // CEK APAKAH SUDAH PERNAH LIAT INTRO CEI?
          final prefs = await SharedPreferences.getInstance();
          final bool hasSeenIntroCei = prefs.getBool('hasSeenIntroCei') ?? false;

          if (!hasSeenIntroCei) {
            // KALO BELUM: Lempar ke Intro Cei (Bawa Email)
            // Nanti di Intro Cei, baru dia redirect ke Pantry
            Navigator.pushReplacementNamed(
              context, 
              AppRoutes.introCeiRoute, 
              arguments: userEmail
            );
          } else {
            // KALO UDAH: Langsung ke Pantry
            Navigator.pushReplacementNamed(
              context, 
              AppRoutes.pantryRoute,
              arguments: userEmail
            );
          }
        }
      } catch (e) {
        _handleSessionError(e);
      }
    } else {
      _handleSessionError(Exception("Sesi valid tapi email null."));
    }
  }

  void _handleSessionError(Object e) {
    if (mounted && !_navigationHandled) {
      _navigationHandled = true;
      Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/icon_chefgenius.png', height: 100),
            const SizedBox(height: 24),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
          ],
        ),
      ),
    );
  }
}