/// Evaluation Context Provider
/// Provides standardized context for RAGAS evaluation testing

import 'chatbot_service.dart'; // Import UserContext from here

/// Standard context for RAGAS evaluation
/// All evaluation queries use this EXACT context
class EvaluationContextProvider {
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STANDARDIZED CONTEXT FOR EVALUATION
  // IMPORTANT: Use this EXACT context for ALL evaluation queries
  // This ensures fair comparison between RAG modes
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  static const List<String> STANDARD_PANTRY = [
    'Rice',
    'Eggs',
    'Chicken',
    'Tomato',
    'Onion',
    'Garlic',
    'Salt',
    'Oil',
    'Spices',
  ];

  static const List<String> STANDARD_DIET_PREFERENCES = [
    'Vegetarian',
  ];

  static const List<String> STANDARD_ALLERGIES = [
    'Nut Allergy',
  ];

  /// Get standardized context for RAGAS evaluation
  static UserContext getStandardContext() {
    return UserContext(
      pantryItems: STANDARD_PANTRY.toList(),
      dietPreferences: STANDARD_DIET_PREFERENCES.toList(),
      allergies: STANDARD_ALLERGIES.toList(),
    );
  }

  /// Get NO context (empty) for baseline evaluation
  static UserContext getNoContext() {
    return UserContext(
      pantryItems: [],
      dietPreferences: [],
      allergies: [],
    );
  }

  /// Get context summary string for logging
  static String getContextSummary() {
    final ctx = getStandardContext();
    return '''
STANDARDIZED EVALUATION CONTEXT:
════════════════════════════════════════════════
Pantry Items (${ctx.pantryItems.length}):
  ${ctx.pantryItems.join(', ')}

Diet Preferences (${ctx.dietPreferences.length}):
  ${ctx.dietPreferences.join(', ')}

Allergies (${ctx.allergies.length}):
  ${ctx.allergies.join(', ')}

🧪 Use this EXACT context for all evaluation queries!
🧪 Ensure fair comparison between RAG modes!
════════════════════════════════════════════════
    ''';
  }
}

/// Usage Example for RAGAS Evaluation:
/// 
/// ```dart
/// // 1. Get standardized context
/// final evalContext = EvaluationContextProvider.getStandardContext();
/// 
/// // 2. Enable evaluation mode in chatbot
/// final chatbot = ChatbotService();
/// chatbot.enableEvaluationMode(evalContext);
/// 
/// // 3. Print context summary
/// print(EvaluationContextProvider.getContextSummary());
/// 
/// // 4. Run evaluation queries
/// // All queries will use the SAME standardized context
/// for (var vignette in vignettes) {
///   final response = await chatbot.sendMessage(vignette.query);
///   // Response uses standardized context (not user-specific)
/// }
/// 
/// // 5. Disable evaluation when done
/// chatbot.disableEvaluationMode();
/// ```
