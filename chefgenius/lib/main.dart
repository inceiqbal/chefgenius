import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORT INI WAJIB BUAT FORMAT TANGGAL ---
import 'package:intl/date_symbol_data_local.dart'; 

import 'app/config/theme.dart';
import 'app/config/routes.dart';
import 'app/data/providers/recipe_provider.dart';
import 'app/data/providers/theme_provider.dart';
import 'app/data/providers/generated_recipe_provider.dart';
import 'app/data/providers/connectivity_provider.dart';
import 'app/data/providers/shopping_list_provider.dart'; // TAMBAHAN BARU
import 'app/data/models/ingredient_model.dart';
import 'app/data/models/recipe_model.dart';
import 'app/data/models/shopping_list_item_model.dart'; // TAMBAHAN BARU
// --------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Format Tanggal Bahasa Indonesia (PENTING!)
  await initializeDateFormatting('id_ID', null);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw Exception(
        'SUPABASE_URL & SUPABASE_KEY tidak ditemukan! '
        'Pastikan Anda nge-run pake --dart-define.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  await Hive.initFlutter();

  // --- REGISTRASI HIVE ADAPTER (WAJIB BUAT CACHE) ---
  if (!Hive.isAdapterRegistered(IngredientAdapter().typeId)) {
    Hive.registerAdapter(IngredientAdapter());
  }
  if (!Hive.isAdapterRegistered(RecipeAdapter().typeId)) {
    Hive.registerAdapter(RecipeAdapter());
  }
  // 🟢 REGISTRASI ADAPTER SHOPPING LIST (JANGAN LUPA!)
  if (!Hive.isAdapterRegistered(ShoppingListItemAdapter().typeId)) {
    Hive.registerAdapter(ShoppingListItemAdapter());
  }
  // ------------------------------------------------

  try {
    if (!Hive.isBoxOpen('userBox')) {
      await Hive.openBox<String>('userBox');
    }
    if (!Hive.isBoxOpen('favoriteBox')) {
      await Hive.openBox<int>('favoriteBox');
    }

    if (!Hive.isBoxOpen('favorite_recipes_cache')) {
      await Hive.openBox<Recipe>('favorite_recipes_cache');
    }
    
    // 🟢 BUKA BOX SHOPPING LIST (WAJIB BIAR BISA OFFLINE)
    if (!Hive.isBoxOpen('shopping_list_box')) {
      await Hive.openBox<ShoppingListItem>('shopping_list_box');
    }

  } catch (e) {
    debugPrint("Error pas buka Hive box: $e");
  }

  // 🟢 Inisialisasi GeneratedRecipeProvider
  final generatedRecipeProvider = GeneratedRecipeProvider();
  await generatedRecipeProvider.loadRecipes();

  // --- SIAPIN "MATA-MATA" INTERNET KITA ---
  final connectivityProvider = ConnectivityProvider();
  connectivityProvider.init(); // Mulai ngedengerin...
  // ----------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RecipeProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => generatedRecipeProvider),
        // --- DAFTARIN "MATA-MATA" INTERNET ---
        ChangeNotifierProvider(create: (context) => connectivityProvider),
        // 🟢 DAFTARIN PROVIDER BELANJA (WAJIB!)
        ChangeNotifierProvider(create: (context) => ShoppingListProvider()),
        // -----------------------------------
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Chef Genius',
          theme: themeProvider.isDarkMode
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          initialRoute: AppRoutes.splashRoute,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}