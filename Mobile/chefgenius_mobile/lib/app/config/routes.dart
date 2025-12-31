import 'package:flutter/material.dart';
import '../../app/data/models/recipe_model.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_form_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/edit_profile_screen.dart';
import '../../features/auth/screens/settings_screen.dart';
import '../../features/auth/screens/about_screen.dart';
import '../../features/auth/screens/terms_screen.dart';
import '../../features/auth/screens/privacy_policy_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../features/mainNav/main_nav_screen.dart'; 
import '../../features/recipe/screens/recipe_list_screen.dart';
import '../../features/recipe/screens/recipe_detail_screen.dart';
import '../../features/recipe/screens/generate_recipe_screen.dart';
import '../../features/recipe/screens/favorite_recipes_screen.dart';
import '../../features/recipe/screens/recipe_search_screen.dart';
import '../../features/recipe/screens/cooking_mode_screen.dart';
import '../../features/shopping_list/screens/shopping_list_screen.dart';
import '../../features/recipe/screens/cooking_history_screen.dart';
import '../../features/intro/screens/intro_cei_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/upload_post_screen.dart';
import '../../features/community/screens/comments_screen.dart';
import '../../features/community/screens/saved_posts_screen.dart';
import '../../features/community/screens/likes_list_screen.dart';
import '../../features/community/screens/post_detail_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';

class AppRoutes {
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordFormRoute = '/reset-password-form';
  static const String updatePasswordRoute = '/update-password'; // 🔥 RUTE BARU: Buat Deep Link Reset Password
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
  static const String introCeiRoute = '/intro-cei';

  // RUTE MEDSOS
  static const String communityRoute = '/community';
  static const String uploadPostRoute = '/upload-post';
  static const String commentsRoute = '/comments';
  static const String savedPostsRoute = '/saved-posts';
  static const String likesListRoute = '/likes-list';
  static const String adminDashboardRoute = '/admin-dashboard';
  // 🔥 RUTE DEEP LINK DARI WEB
  static const String deepLinkPostDetailRoute = '/post-detail-deeplink';


  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splashRoute:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case introCeiRoute:
        final email = settings.arguments as String?;
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

      // 🔥 CASE BARU: Arahkan ke form ganti password saat link diklik
      case updatePasswordRoute:
        return MaterialPageRoute(builder: (_) => const ResetPasswordFormScreen());

      case pantryRoute:
        final email = settings.arguments as String?;
        if (email == null) {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        return MaterialPageRoute(builder: (_) => MainNavScreen(email: email));

      case profileRoute:
        final args = settings.arguments;
        // 🔥 LOGIC UPDATE: Support kirim ID Postingan buat Auto-Open + isFromDeepLink flag
        if (args is String) {
            if (args.contains('@')) {
              return MaterialPageRoute(builder: (_) => ProfileScreen(email: args));
            } else {
              return MaterialPageRoute(builder: (_) => ProfileScreen(userId: args));
            }
        } else if (args is Map<String, dynamic>) {
            // FIX: Gunakan isFromDeepLink explicit dari arguments
            return MaterialPageRoute(builder: (_) => ProfileScreen(
              userId: args['userId'],
              initialPostId: args['initialPostId'], 
              isFromDeepLink: args['isFromDeepLink'] ?? false, // FIX: Default false jika tidak ada
            ));
        }
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

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
        return MaterialPageRoute(builder: (_) => RecipeListScreen(recipes: args ?? []));

      case recipeDetailRoute:
        final args = settings.arguments as Recipe?;
        if (args == null) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Resep tidak ditemukan"))));
        }
        return MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: args));

      case recipeSearchRoute:
        return MaterialPageRoute(builder: (_) => const RecipeSearchScreen());

      case generateRecipeRoute:
        return MaterialPageRoute(builder: (_) => const GenerateRecipeScreen());

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

      case communityRoute:
        return MaterialPageRoute(builder: (_) => const CommunityScreen());

      case uploadPostRoute:
        return MaterialPageRoute(builder: (_) => const UploadPostScreen());

      // CASE UNTUK POST DETAIL SCREEN (Untuk rute Deep Link dari Web)
      case deepLinkPostDetailRoute:
        final postId = settings.arguments as String?;
        if (postId == null) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Error: Post ID Deep Link"))));
        }
        return MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)); 

      case commentsRoute:
        final args = settings.arguments;
        String? postId;
        String? highlightCommentId;

        if (args is String) {
          postId = args;
        } else if (args is Map) {
          postId = args['postId'];
          highlightCommentId = args['highlightCommentId']?.toString();
        }

        if (postId == null) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Error: No Post ID"))));
        }
        return MaterialPageRoute(builder: (_) => CommentsScreen(postId: postId!, highlightCommentId: highlightCommentId));

      case savedPostsRoute:
        return MaterialPageRoute(builder: (_) => const SavedPostsScreen());

      case likesListRoute:
        final postId = settings.arguments as String?;
        if (postId == null) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Error: No Post ID"))));
        }
        return MaterialPageRoute(builder: (_) => LikesListScreen(postId: postId));

      case adminDashboardRoute:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}