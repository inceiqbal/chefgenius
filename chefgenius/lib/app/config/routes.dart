import 'package:flutter/material.dart';
import 'package:chefgenius/app/data/models/recipe_model.dart';
import 'package:chefgenius/features/auth/screens/splash_screen.dart';
import 'package:chefgenius/features/auth/screens/onboarding_screen.dart';
import 'package:chefgenius/features/auth/screens/login_screen.dart';
import 'package:chefgenius/features/auth/screens/register_screen.dart';
import 'package:chefgenius/features/auth/screens/forgot_password_screen.dart';
import 'package:chefgenius/features/auth/screens/reset_password_form_screen.dart';
import 'package:chefgenius/features/auth/screens/profile_screen.dart';
import 'package:chefgenius/features/auth/screens/edit_profile_screen.dart';
import 'package:chefgenius/features/auth/screens/settings_screen.dart';
import 'package:chefgenius/features/auth/screens/about_screen.dart';
import 'package:chefgenius/features/auth/screens/terms_screen.dart';
import 'package:chefgenius/features/auth/screens/privacy_policy_screen.dart';
import 'package:chefgenius/features/auth/screens/change_password_screen.dart';
import 'package:chefgenius/features/pantry/screens/pantry_screen.dart';
import 'package:chefgenius/features/recipe/screens/recipe_list_screen.dart';
import 'package:chefgenius/features/recipe/screens/recipe_detail_screen.dart';
import 'package:chefgenius/features/recipe/screens/generate_recipe_screen.dart';
import 'package:chefgenius/features/recipe/screens/favorite_recipes_screen.dart';
import 'package:chefgenius/features/recipe/screens/recipe_search_screen.dart';
import 'package:chefgenius/features/recipe/screens/cooking_mode_screen.dart';
import 'package:chefgenius/features/shopping_list/screens/shopping_list_screen.dart';
import 'package:chefgenius/features/recipe/screens/cooking_history_screen.dart';
import 'package:chefgenius/features/intro/screens/intro_cei_screen.dart';

class AppRoutes {
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordFormRoute = '/reset-password-form';
  static const String termsRoute = '/terms';
  static const String privacyPolicyRoute = '/privacy-policy';
  static const String changePasswordRoute = '/change-password';
  static const String pantryRoute = '/pantry';
  static const String profileRoute = '/profile';
  static const String editProfileRoute = '/edit-profile';
  static const String settingsRoute = '/settings';
  static const String aboutRoute = '/about';
  static const String recipeListRoute = '/recipe-list';
  static const String recipeDetailRoute = '/recipe-detail';
  static const String recipeSearchRoute = '/recipe-search';
  static const String generateRecipeRoute = '/generate-recipe';
  static const String favoriteRecipesRoute = '/favorite-recipes';
  static const String cookingModeRoute = '/cooking-mode';
  static const String shoppingListRoute = '/shopping-list';
  static const String historyRoute = '/history';
  
  // KONSTANTA RUTE BARU: INTRO CEI
  static const String introCeiRoute = '/intro-cei';

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splashRoute:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      // UPDATE CASE INI: Nangkep email dari arguments
      case introCeiRoute:
        final email = settings.arguments as String?;
        // Kirim email ke IntroCeiScreen (kalo null kita kasih string kosong buat jaga2)
        return MaterialPageRoute(builder: (_) => IntroCeiScreen(email: email ?? ''));

      case onboardingRoute:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case loginRoute:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case registerRoute:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case forgotPasswordRoute:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case resetPasswordFormRoute:
        return MaterialPageRoute(builder: (_) => const ResetPasswordFormScreen());

      case pantryRoute:
        final email = settings.arguments as String?;
        if (email == null) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        return MaterialPageRoute(
            builder: (_) => PantryScreenWithShowcase(email: email));

      case profileRoute:
        final email = settings.arguments as String?;
        if (email == null) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        return MaterialPageRoute(builder: (_) => ProfileScreen(email: email));

      case editProfileRoute:
        final email = settings.arguments as String?;
        if (email == null) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        return MaterialPageRoute(builder: (_) => EditProfileScreen(email: email));

      case settingsRoute:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case aboutRoute:
        return MaterialPageRoute(builder: (_) => const AboutScreen());

      case termsRoute:
        return MaterialPageRoute(builder: (_) => const TermsScreen());

      case privacyPolicyRoute:
        return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());

      case changePasswordRoute:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());

      case recipeListRoute:
        final args = settings.arguments as List<Recipe>?;
        return MaterialPageRoute(
            builder: (_) => RecipeListScreen(recipes: args ?? []));

      case recipeDetailRoute:
        final args = settings.arguments as Recipe?;
        if (args == null) {
          return MaterialPageRoute(
              builder: (_) => const Scaffold(
                  body: Center(child: Text("Resep tidak ditemukan"))));
        }
        return MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: args));

      case recipeSearchRoute:
        return MaterialPageRoute(builder: (_) => const RecipeSearchScreen());

      case generateRecipeRoute:
        return MaterialPageRoute(
            builder: (_) => const GenerateRecipeScreenWithShowcase());

      case favoriteRecipesRoute:
        return MaterialPageRoute(builder: (_) => const FavoriteRecipesScreen());

      case cookingModeRoute:
        final args = settings.arguments as Recipe?;
        if (args == null) {
          return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
        return MaterialPageRoute(
            builder: (_) => CookingModeScreen(recipe: args),
            fullscreenDialog: true);

      case shoppingListRoute:
        return MaterialPageRoute(builder: (_) => const ShoppingListScreen());

      case historyRoute:
        return MaterialPageRoute(builder: (_) => const CookingHistoryScreen());

      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}