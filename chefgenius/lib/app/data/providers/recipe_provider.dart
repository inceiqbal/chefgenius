import 'package:flutter/foundation.dart';
import '../../services/recommendation_service.dart';
import '../models/recipe_model.dart';

class RecipeProvider extends ChangeNotifier {
  final RecommendationService _service = RecommendationService();
  List<Recipe> _recipes = [];
  bool _isLoading = false;

  List<Recipe> get recipes => _recipes;
  bool get isLoading => _isLoading;

  Future<void> getRecommendations(List<String> pantryItems) async {
    _isLoading = true;
    notifyListeners();

    _recipes = await _service.getRecommendations(pantryItems);

    _isLoading = false;
    notifyListeners();
  }
}