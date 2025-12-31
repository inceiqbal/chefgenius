import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:app_links/app_links.dart'; 
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/notification_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _appLinks = AppLinks(); 
  bool _navigationHandled = false;
  StreamSubscription<AuthState>? _authSubscription; // 🔥 1. Variable Subscription

  @override
  void initState() {
    super.initState();
    _setupAuthListener(); // 🔥 2. Pasang Listener Auth DULUAN
    _initializeApp();
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel(); // 🔥 3. Bersihin biar ga memory leak
    super.dispose();
  }

  // 🔥 4. Logic Satpam Auth
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      // Kalau Supabase teriak "PASSWORD RECOVERY", kita langsung tangkep!
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("🔑 SPLASH: PASSWORD RECOVERY EVENT DETECTED!");
        
        // Stop logic navigasi lain (biar ga ke Home/Login)
        setState(() {
          _navigationHandled = true;
        });

        // Langsung lempar ke halaman Ganti Password
        if (mounted) {
          // Kasih delay dikit biar transisinya mulus
          Future.delayed(const Duration(milliseconds: 100), () {
            Navigator.pushReplacementNamed(context, AppRoutes.updatePasswordRoute);
          });
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    // 1. Cek Deep Link (Cold Start)
    bool handledByDeepLink = await _initDeepLinks();

    // 2. Kalau Deep Link berhasil di-handle (langsung navigasi), STOP.
    if (handledByDeepLink) {
      debugPrint("🚀 Deep Link handled during Splash. Stopping normal Auth flow.");
      return;
    }

    // 3. Lanjut cek status login biasa
    _checkInitialRoute();
  }

  Future<bool> _initDeepLinks() async {
    try {
      // Cek link awal
      final initialUri = await _appLinks.getInitialLink(); 
      if (initialUri != null) {
        debugPrint("🔗 Initial Deep Link Detected: $initialUri");
        return await _handleDeepLinkUri(initialUri); 
      }
    } on PlatformException {
      debugPrint("Warning: Failed to get initial URI.");
    }
    return false;
  }

  // Fungsi Parsing & Handling Deep Link yang Lebih Kuat
  Future<bool> _handleDeepLinkUri(Uri uri) async {
    String? postId;

    // 🔥 FIX: Parsing URL yang tahan banting (Handle Triple Slash ///)
    // Cek pathSegments dulu karena lebih reliable
    if (uri.pathSegments.contains('post')) {
      final index = uri.pathSegments.indexOf('post');
      if (index + 1 < uri.pathSegments.length) {
        postId = uri.pathSegments[index + 1];
      }
    } 
    // Fallback: Cek host kalau structure-nya chefgenius://post/ID
    else if (uri.host == 'post') {
      if (uri.pathSegments.isNotEmpty) {
        postId = uri.pathSegments[0];
      }
    }
    // Fallback: Query param
    else {
      postId = uri.queryParameters['id'];
    }

    if (postId != null && postId.isNotEmpty && postId != 'post') {
        debugPrint("🔗 Found Post ID: $postId");

        Session? session = Supabase.instance.client.auth.currentSession;
        
        if (session == null) {
          debugPrint("⏳ Session null, mencoba refresh session sebentar...");
          try {
            // Coba pulihkan sesi (timeout 2 detik biar gak lama nunggu)
            final response = await Supabase.instance.client.auth.refreshSession().timeout(const Duration(seconds: 2));
            session = response.session;
          } catch (_) {
            // Ignore error if refresh fails
          }
        }

        if (session == null) {
          // KONDISI 1: User Beneran Belum Login -> Simpan ID
          if (!_navigationHandled) {
             final prefs = await SharedPreferences.getInstance();
             await prefs.setString('deferred_deeplink_post_id', postId);
             debugPrint("⏳ User belum login. Deep Link disimpan di Prefs.");
          }
          return false; // Return False biar lanjut ke Login Screen
        } else {
          // KONDISI 2: User Sudah Login -> Langsung Gass ke Postingan
          if (!_navigationHandled) {
            _navigationHandled = true;
            debugPrint("✅ User login. Navigasi langsung ke Post Detail.");
            Navigator.pushReplacementNamed(
              context, 
              AppRoutes.deepLinkPostDetailRoute, 
              arguments: postId
            );
            return true; // Return True -> STOP flow normal
          }
        }
    }
    return false;
  }

  // Logic Routing Utama
  Future<void> _checkInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // 🔥 CEK PENTING: Kalau udah di-handle sama listener Auth atau DeepLink, jangan lanjut!
    if (!mounted || _navigationHandled) {
      debugPrint("🛑 Navigation interrupted because it was already handled (Recovery/DeepLink).");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (!hasSeenOnboarding) {
        _navigationHandled = true;
        Navigator.pushReplacementNamed(context, AppRoutes.onboardingRoute);
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        _handleUserLoggedIn(session);
      } else {
        _navigationHandled = true;
        Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
      }

    } catch (e) {
      debugPrint("Error check initial route: $e");
      if (!_navigationHandled) {
        _navigationHandled = true;
        Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
      }
    }
  }

  Future<void> _handleUserLoggedIn(Session session) async {
    if (_navigationHandled) return; // Guard clause extra

    final user = session.user;
    final emailConfirmedAt = user.emailConfirmedAt;
    final createdAt = user.createdAt;
    
    final prefs = await SharedPreferences.getInstance();
    final hasLoggedInBefore = prefs.getBool('has_logged_in_${user.id}') ?? false;

    // Logic Verifikasi Email (Hanya user baru)
    if (!hasLoggedInBefore && emailConfirmedAt != null) {
      final confirmedTime = DateTime.parse(emailConfirmedAt);
      final createdTime = DateTime.parse(createdAt);
      final now = DateTime.now().toUtc();
      
      final isRecentlyConfirmed = now.difference(confirmedTime).inMinutes < 5;
      final isNewAccount = now.difference(createdTime).inMinutes < 10;
      
      if (isRecentlyConfirmed && isNewAccount) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          _navigationHandled = true;
          Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
          
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Email berhasil diverifikasi! Silakan login ya! 🎉"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          });
        }
        return;
      }
    }

    _prepareUserSessionAndNavigate(session);
  }

  Future<void> _prepareUserSessionAndNavigate(Session session) async {
    if (!mounted || _navigationHandled) return;
    
    // FIX: Reinitialize notification provider for current user session
    // This ensures badge count is correct after auto-login
    try {
      Provider.of<NotificationProvider>(context, listen: false).reinit();
    } catch (e) {
      debugPrint('Warning: Could not reinit NotificationProvider: $e');
    }
    
    final userEmail = session.user.email;
    final prefs = await SharedPreferences.getInstance();
    
    // Cek lagi apakah ada deferred link (Double check)
    final deferredPostId = prefs.getString('deferred_deeplink_post_id');
    
    if (deferredPostId != null && deferredPostId.isNotEmpty) {
      debugPrint("🚀 Deferred Deep Link Found (Session Check): $deferredPostId");
      await prefs.remove('deferred_deeplink_post_id'); 
      
      if (!_navigationHandled) {
        _navigationHandled = true;
        Navigator.pushReplacementNamed(
            context, 
            AppRoutes.deepLinkPostDetailRoute, 
            arguments: deferredPostId
        );
      }
      return;
    }
    
    // Normal Flow (Ke Home/Intro)
    if (userEmail != null) {
      try {
        if (!Hive.isBoxOpen('pantry_$userEmail')) {
          await Hive.openBox<String>('pantry_$userEmail');
        }

        if (!_navigationHandled && mounted) {
          _navigationHandled = true;
          final bool hasSeenIntroCei = prefs.getBool('hasSeenIntroCei') ?? false;

          if (!hasSeenIntroCei) {
            Navigator.pushReplacementNamed(context, AppRoutes.introCeiRoute, arguments: userEmail);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.pantryRoute, arguments: userEmail);
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