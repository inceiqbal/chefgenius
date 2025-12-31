// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/services/fcm_service.dart'; 

import 'app/config/theme.dart';
import 'app/config/routes.dart';
import 'app/data/providers/recipe_provider.dart';
import 'app/data/providers/theme_provider.dart';
import 'app/data/providers/generated_recipe_provider.dart';
import 'app/data/providers/connectivity_provider.dart';
import 'app/data/providers/shopping_list_provider.dart';
import 'app/data/providers/language_provider.dart';
import 'app/data/providers/notification_provider.dart';
import 'app/data/providers/recipe_rating_provider.dart';
import 'features/community/providers/community_provider.dart';
import 'app/data/models/ingredient_model.dart';
import 'app/data/models/recipe_model.dart';
import 'app/data/models/shopping_list_item_model.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _notificationsInitialized = false;
bool _permissionRequested = false;

Future<void> _initNotifications() async {
  if (_notificationsInitialized) return;
  _notificationsInitialized = true;

  const android = AndroidInitializationSettings('@mipmap/launcher_icon');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: android,
    iOS: ios,
  );

  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      debugPrint("Notifikasi diklik: ${response.payload}");
      if (response.actionId == 'stop_alarm') {
        try {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
            notifProvider.notifyAlarmStopped();
          }
        } catch (e) {
          debugPrint('Error handle stop_alarm action: $e');
        }
      }
    },
  );

  final androidImplementation = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation != null) {
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'alarm_channel',
      'Alarm Timer',
      description: 'Notifikasi alarm timer dengan suara custom yang bypass Do Not Disturb',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('kitchen_timer'),
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 255, 0, 0),
    );

    const AndroidNotificationChannel timerChannel = AndroidNotificationChannel(
      'cooking_timer_channel',
      'Timer Masak',
      description: 'Notifikasi untuk timer memasak yang sedang berjalan',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await androidImplementation.createNotificationChannel(alarmChannel);
    await androidImplementation.createNotificationChannel(timerChannel);
    
    // FIX: Tambahkan channel untuk aktivitas sosial (like, komen, share, save)
    const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      'chefgenius_channel',
      'Aktivitas Sosial',
      description: 'Notifikasi untuk like, komentar, share, dan save',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidImplementation.createNotificationChannel(socialChannel);
    
    debugPrint("✅ Notification channels dibuat (alarm, timer, social)");
  }

  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
  } catch (e) {
    debugPrint("Warning: Gagal set lokasi timezone spesifik, menggunakan default UTC/Local. Error: $e");
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> scheduleAlarmNotification({
  required DateTime scheduledTime,
  String? payload,
}) async {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'alarm_channel',
    'Alarm Timer',
    channelDescription: 'Notifikasi alarm timer dengan suara custom',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('kitchen_timer'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), 
    enableLights: true,
    ledColor: const Color.fromARGB(255, 255, 0, 0),
    ledOnMs: 1000,
    ledOffMs: 500,
    actions: const <AndroidNotificationAction>[
      AndroidNotificationAction(
        'stop_alarm',
        'Matikan Alarm',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
    ticker: 'Alarm Timer',
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    autoCancel: false,
    ongoing: true,
    showWhen: true,
    usesChronometer: false,
    timeoutAfter: 30000,
    styleInformation: const BigTextStyleInformation(
      'Timer memasak Anda telah selesai! Segera cek masakan Anda.',
      contentTitle: '⏰ Timer Selesai!',
      summaryText: 'Chef Genius',
    ),
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentSound: true,
    sound: 'kitchen_timer.mp3',
    interruptionLevel: InterruptionLevel.critical,
    presentAlert: true,
    presentBadge: true,
    presentBanner: true,
    categoryIdentifier: 'alarmCategory',
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  try {
    await notificationsPlugin.zonedSchedule(
      999,
      '⏰ Timer Selesai!',
      'Waktu memasak sudah habis! Klik untuk matikan alarm.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
    debugPrint('✅ Alarm dijadwalkan untuk: ${scheduledTime.toString()}');
  } catch (e) {
    debugPrint('❌ Gagal menjadwalkan alarm: $e');
  }
}

Future<void> showImmediateAlarmNotification({String? payload}) async {
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'alarm_channel',
    'Alarm Timer',
    channelDescription: 'Notifikasi alarm timer dengan suara custom',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('kitchen_timer'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    enableLights: true,
    ledColor: const Color.fromARGB(255, 255, 0, 0),
    ledOnMs: 1000,
    ledOffMs: 500,
    actions: const <AndroidNotificationAction>[
      AndroidNotificationAction(
        'stop_alarm',
        'Matikan Alarm',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
    ticker: 'Alarm Timer',
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    autoCancel: false,
    ongoing: true,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentSound: true,
    sound: 'kitchen_timer.mp3',
    interruptionLevel: InterruptionLevel.critical,
    presentAlert: true,
    presentBadge: true,
    presentBanner: true,
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  try {
    await notificationsPlugin.show(
      999,
      '⏰ Timer Selesai!',
      'Waktu memasak sudah habis! Klik untuk matikan alarm.',
      notificationDetails,
      payload: payload,
    );
    debugPrint('✅ Alarm ditampilkan sekarang');
  } catch (e) {
    debugPrint('❌ Gagal menampilkan alarm: $e');
  }
}

Future<void> cancelAllAlarmsOnAppKill() async {
  try {
    await notificationsPlugin.cancelAll();
    debugPrint('✅ Semua alarm dibatalkan karena aplikasi dimatikan paksa.');
  } catch (e) {
    debugPrint('❌ Gagal membatalkan alarm saat app kill: $e');
  }
}

class MyAppWithNavKey extends StatelessWidget {
  const MyAppWithNavKey({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize Firebase for FCM Push Notifications
  try {
    await Firebase.initializeApp();
    debugPrint("✅ Firebase Initialized");
  } catch (e) {
    debugPrint("❌ Failed to init Firebase: $e");
  }

  try {
    await _initNotifications();
  } catch (e) {
    debugPrint("❌ ERROR FATAL INIT NOTIFICATIONS: $e");
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    debugPrint('⚠️ WARNING: SUPABASE_URL/KEY kosong. Cek --dart-define saat build.');
  } else {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: false,
      );
      debugPrint("✅ Supabase Initialized");
    } catch (e) {
      debugPrint("❌ Gagal Init Supabase: $e");
    }
  }

  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(IngredientAdapter().typeId)) {
      Hive.registerAdapter(IngredientAdapter());
    }
    if (!Hive.isAdapterRegistered(RecipeAdapter().typeId)) {
      Hive.registerAdapter(RecipeAdapter());
    }
    if (!Hive.isAdapterRegistered(ShoppingListItemAdapter().typeId)) {
      Hive.registerAdapter(ShoppingListItemAdapter());
    }

    if (!Hive.isBoxOpen('userBox')) await Hive.openBox<String>('userBox');
    if (!Hive.isBoxOpen('favoriteBox')) await Hive.openBox<int>('favoriteBox');
    if (!Hive.isBoxOpen('favorite_recipes_cache')) {
      await Hive.openBox<Recipe>('favorite_recipes_cache');
    }
    if (!Hive.isBoxOpen('shopping_list_box')) {
      await Hive.openBox<ShoppingListItem>('shopping_list_box');
    }
  } catch (e) {
    debugPrint("❌ Error Setup Hive: $e");
  }

  final generatedRecipeProvider = GeneratedRecipeProvider();
  generatedRecipeProvider.loadRecipes();

  final connectivityProvider = ConnectivityProvider();
  connectivityProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RecipeProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider.value(value: generatedRecipeProvider),
        ChangeNotifierProvider(create: (context) => connectivityProvider),
        ChangeNotifierProvider(create: (context) => ShoppingListProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()..init()),
        ChangeNotifierProvider(create: (context) => CommunityProvider()),
        ChangeNotifierProvider(create: (context) => RecipeRatingProvider()),
      ],
      child: const MyAppWithNavKey(),
    ),
  );
}

Future<void> _requestNotificationPermission() async {
  if (_permissionRequested) return;
  _permissionRequested = true;

  final androidImplementation = notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation == null) return;

  final bool? alreadyGranted = await androidImplementation.areNotificationsEnabled();
  if (alreadyGranted == true) {
    debugPrint("✅ Notification permission already granted");
  } else {
    for (int attempt = 1; attempt <= 3; attempt++) {
      await Future.delayed(Duration(seconds: attempt));
      try {
        await androidImplementation.requestNotificationsPermission();
        debugPrint("✅ Notification permission requested successfully");
        break;
      } catch (e) {
        debugPrint("Warning: Permission request attempt $attempt failed: $e");
        if (attempt == 3) {
          debugPrint("⚠️ Giving up on notification permission request");
        }
      }
    }
  }

  try {
    final bool? exactAlarmGranted = await androidImplementation.canScheduleExactNotifications();
    if (exactAlarmGranted == false) {
      await androidImplementation.requestExactAlarmsPermission();
      debugPrint("✅ Exact alarm permission requested");
    } else {
      debugPrint("✅ Exact alarm permission already granted");
    }
  } catch (e) {
    debugPrint("Warning: Exact alarm permission not available: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription; // 🔥 1. Variable Subscription
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    _initDeepLinks();
    _initAuthListener(); // 🔥 2. Panggil Listener di sini!
    
    // Set flag ke false setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFirstLaunch = false;
        });
      }
    });
  }

  // 🔥 3. Fungsi Listener Auth (Ini yang bikin redirect jalan!)
  void _initAuthListener() {
    debugPrint("🎧 Auth Listener Initialized: Siap mendengarkan reset password...");
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      debugPrint("🔔 Auth Event Detected: $event");
      
      // Initialize FCM when user signs in or on initial session
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        try {
          await FCMService().init();
          debugPrint("🔔 FCM Service initialized after sign in");
        } catch (e) {
          debugPrint("❌ Error initializing FCM: $e");
        }
      }
      
      // Clear FCM token when user signs out
      if (event == AuthChangeEvent.signedOut) {
        try {
          await FCMService().onUserLogout();
          debugPrint("🔔 FCM token cleared on sign out");
        } catch (e) {
          debugPrint("❌ Error clearing FCM token: $e");
        }
      }
      
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("🔑 PASSWORD RECOVERY EVENT! Redirecting to Update Password Screen...");
        
        // Jeda dikit biar gak tabrakan sama splash screen
        Future.delayed(const Duration(milliseconds: 500), () {
          // Pastikan route '/update-password' atau 'AppRoutes.updatePasswordRoute' ada di routes.dart kamu!
          // Aku pake string hardcode dulu biar aman, sesuaikan kalau kamu pakai constant.
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/update-password', (route) => false); 
        });
      }
    });
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 [MAIN] Deep Link Stream Diterima: $uri');
      
      if (_isFirstLaunch) {
        debugPrint("⏳ [MAIN] Ignoring stream because it's first launch (let Splash handle it)");
        return;
      }
      
      _handleDeepLinkNavigation(uri);
    }, onError: (err) {
      debugPrint('❌ [MAIN] Deep Link Error: $err');
    });
  }

  void _handleDeepLinkNavigation(Uri uri) async {
    String? postId;

    // Parsing URL yang Tahan Banting
    if (uri.pathSegments.contains('post')) {
      final index = uri.pathSegments.indexOf('post');
      if (index + 1 < uri.pathSegments.length) {
        postId = uri.pathSegments[index + 1];
      }
    } 
    else if (uri.host == 'post') {
      if (uri.pathSegments.isNotEmpty) {
        postId = uri.pathSegments[0];
      }
    }
    else {
      postId = uri.queryParameters['id'];
    }

    if (postId != null && postId.isNotEmpty && postId != 'post') {
      debugPrint("🔗 [MAIN] Navigasi ke Post ID: $postId (isFirstLaunch=$_isFirstLaunch)");
      debugPrint("🔍 [MAIN] Navigator canPop: ${navigatorKey.currentState?.canPop()}");
      
      Session? session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
         try {
            final response = await Supabase.instance.client.auth.refreshSession();
            session = response.session;
         } catch (_) {}
      }
      
      if (session != null) {
        debugPrint("✅ [MAIN] User Login: Clearing Stack & Pushing Route...");
        
        
        // Pakai (route) => route.isFirst biar dia hapus SEMUA halaman di atas Home/Root.
        // Jadi tumpukan selalu bersih: [HOME, POST BARU]
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.deepLinkPostDetailRoute, 
          (route) => route.isFirst, // <-- INI MANTRA SAKTINYA
          arguments: postId,
        );
        debugPrint("🔍 [MAIN] pushNamedAndRemoveUntil called for postId=$postId");
      } else {
        debugPrint("❌ [MAIN] User belum login, arahkan ke login");
        navigatorKey.currentState?.pushNamed(AppRoutes.loginRoute);
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel(); // 🔥 4. Jangan lupa cancel biar gak bocor memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, langProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Chef Genius',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          locale: langProvider.appLocale,
          supportedLocales: const [
            Locale('id', 'ID'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.splashRoute,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}