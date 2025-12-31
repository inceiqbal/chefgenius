import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeRatingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // Cache ratings per recipe
  final Map<int, double> _averageRatings = {};
  final Map<int, int> _ratingCounts = {};
  final Map<int, int> _userRatings = {}; // recipeId -> user's rating
  final Map<int, bool> _isLoading = {};

  double getAverageRating(int recipeId) => _averageRatings[recipeId] ?? 0.0;
  int getRatingCount(int recipeId) => _ratingCounts[recipeId] ?? 0;
  int? getUserRating(int recipeId) => _userRatings[recipeId];
  bool isLoading(int recipeId) => _isLoading[recipeId] ?? false;

  /// Load rating data for a specific recipe
  Future<void> loadRating(int recipeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading[recipeId] = true;
    notifyListeners();

    try {
      // Get average rating and count using RPC
      final statsResult = await _supabase
          .rpc('get_recipe_rating_stats', params: {'p_recipe_id': recipeId});

      if (statsResult != null && statsResult is List && statsResult.isNotEmpty) {
        final stats = statsResult[0];
        _averageRatings[recipeId] = (stats['average_rating'] ?? 0).toDouble();
        _ratingCounts[recipeId] = stats['rating_count'] ?? 0;
      } else {
        _averageRatings[recipeId] = 0.0;
        _ratingCounts[recipeId] = 0;
      }

      // Get user's rating for this recipe
      final userRatingResult = await _supabase
          .from('recipe_ratings')
          .select('rating')
          .eq('recipe_id', recipeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (userRatingResult != null) {
        _userRatings[recipeId] = userRatingResult['rating'] as int;
      } else {
        _userRatings.remove(recipeId);
      }
    } catch (e) {
      debugPrint('Error loading recipe rating: $e');
    } finally {
      _isLoading[recipeId] = false;
      notifyListeners();
    }
  }

  /// Submit or update user's rating for a recipe
  Future<bool> submitRating(int recipeId, int rating) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    if (rating < 1 || rating > 5) return false;

    try {
      // Upsert the rating (insert or update if exists)
      await _supabase.from('recipe_ratings').upsert({
        'recipe_id': recipeId,
        'user_id': userId,
        'rating': rating,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'recipe_id,user_id');

      // Update local cache
      _userRatings[recipeId] = rating;

      // Reload stats to get new average
      await _loadStats(recipeId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error submitting recipe rating: $e');
      return false;
    }
  }

  /// Delete user's rating for a recipe
  Future<bool> deleteRating(int recipeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase
          .from('recipe_ratings')
          .delete()
          .eq('recipe_id', recipeId)
          .eq('user_id', userId);

      _userRatings.remove(recipeId);
      await _loadStats(recipeId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe rating: $e');
      return false;
    }
  }

  Future<void> _loadStats(int recipeId) async {
    try {
      final statsResult = await _supabase
          .rpc('get_recipe_rating_stats', params: {'p_recipe_id': recipeId});

      if (statsResult != null && statsResult is List && statsResult.isNotEmpty) {
        final stats = statsResult[0];
        _averageRatings[recipeId] = (stats['average_rating'] ?? 0).toDouble();
        _ratingCounts[recipeId] = stats['rating_count'] ?? 0;
      } else {
        _averageRatings[recipeId] = 0.0;
        _ratingCounts[recipeId] = 0;
      }
    } catch (e) {
      debugPrint('Error loading recipe stats: $e');
    }
  }

  /// Clear cached data for a specific recipe
  void clearCache(int recipeId) {
    _averageRatings.remove(recipeId);
    _ratingCounts.remove(recipeId);
    _userRatings.remove(recipeId);
    notifyListeners();
  }

  /// Clear all cached data
  void clearAllCache() {
    _averageRatings.clear();
    _ratingCounts.clear();
    _userRatings.clear();
    notifyListeners();
  }
}
