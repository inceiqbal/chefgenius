/// Halal Validator Utility
/// Validates ingredients based on Islamic jurisprudence (Quran & Hadith)
class HalalValidator {
  /// Comprehensive non-halal blacklist based on Islamic sources
  static const List<String> nonHalalKeywords = [
    // === BABI (QS. Al-Baqarah 2:173, Al-Ma'idah 5:3) ===
    'pork', 'babi', 'bacon', 'ham', 'lard', 'pancetta', 'prosciutto',
    'salami', 'sausage babi', 'pork belly', 'pork chop', 'pork loin',
    'pork ribs', 'chorizo', 'pepperoni', 'gelatin babi', 'pig',
    
    // === ALKOHOL / KHAMR (QS. Al-Ma'idah 5:90) ===
    'alcohol', 'wine', 'beer', 'vodka', 'whiskey', 'whisky', 'rum',
    'brandy', 'sake', 'soju', 'tequila', 'gin', 'liquor', 'liqueur',
    'champagne', 'mirin', 'cooking wine', 'rice wine', 'arak', 'tuak',
    
    // === DARAH (QS. Al-Ma'idah 5:3) ===
    'blood', 'darah', 'blood sausage', 'black pudding', 'blood cake',
    
    // === BANGKAI / CARRION (QS. Al-Ma'idah 5:3) ===
    'carrion', 'bangkai',
    
    // === BINATANG BUAS BERTARING (Hadith Sahih Muslim) ===
    'dog', 'anjing', 'wolf', 'lion', 'tiger', 'leopard', 'bear',
    'hyena', 'fox', 'cat meat', 'daging kucing',
    
    // === BURUNG PEMANGSA BERKUKU (Hadith) ===
    'eagle', 'hawk', 'falcon', 'vulture', 'owl', 'crow', 'raven',
    
    // === KELEDAI JINAK (Hadith Sahih Bukhari) ===
    'donkey', 'keledai', 'mule', 'bagal',
    
    // === HEWAN MENJIJIKKAN (Hadith) ===
    'rat', 'tikus', 'mouse', 'snake', 'ular', 'scorpion', 'kalajengking',
    'frog', 'kodok', 'katak', 'lizard', 'gecko', 'cicak',
    
    // === SERANGGA (kecuali belalang) ===
    'insect', 'serangga', 'worm', 'cacing', 'maggot', 'belatung',
    'cockroach', 'kecoak', 'beetle', 'kumbang',
  ];

  /// Validate a recipe and return status + detected non-halal ingredients
  /// 
  /// Returns:
  /// - 'status': 'Halal' or 'Non-Halal (Detected)'
  /// - 'detected': List of detected non-halal keywords
  static Map<String, dynamic> validate(Map<String, dynamic> recipeJson) {
    try {
      final List<String> tokens = [];
      final List<String> detectedNonHalal = [];

      void addToken(dynamic v) {
        if (v == null) return;
        if (v is String) {
          tokens.add(v.toLowerCase());
        } else if (v is List) {
          for (var e in v) {
            if (e == null) continue;
            if (e is Map && e.containsKey('name')) {
              tokens.add(e['name'].toString().toLowerCase());
            } else {
              tokens.add(e.toString().toLowerCase());
            }
          }
        } else if (v is Map) {
          if (v.containsKey('name')) {
            tokens.add(v['name'].toString().toLowerCase());
          } else {
            for (var val in v.values) {
              if (val != null) tokens.add(val.toString().toLowerCase());
            }
          }
        } else {
          tokens.add(v.toString().toLowerCase());
        }
      }

      // Collect all text from recipe
      addToken(recipeJson['title']);
      addToken(recipeJson['description']);
      addToken(recipeJson['main_ingredients']);
      addToken(recipeJson['steps']);
      addToken(recipeJson['all_ingredients']);
      addToken(recipeJson['ingredients']);

      final content = tokens.join(' ');

      // Check for non-halal keywords using word boundary to avoid false positives
      // Example: 'gin' should not match 'goreng', 'rum' should not match 'garum'
      for (var keyword in nonHalalKeywords) {
        // Use regex with word boundary for accurate matching
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
        if (regex.hasMatch(content)) {
          if (!detectedNonHalal.contains(keyword)) {
            detectedNonHalal.add(keyword);
          }
        }
      }

      if (detectedNonHalal.isNotEmpty) {
        return {
          'status': 'Non-Halal (Detected)',
          'detected': detectedNonHalal,
        };
      }

      // No non-halal detected, trust AI's label or default to Halal
      final rawLabel = recipeJson['halal_status']?.toString() ?? '';
      if (rawLabel.toLowerCase().contains('non-halal') || 
          rawLabel.toLowerCase().contains('non halal')) {
        return {
          'status': rawLabel,
          'detected': <String>[],
        };
      }

      return {
        'status': 'Halal',
        'detected': <String>[],
      };
    } catch (e) {
      return {
        'status': recipeJson['halal_status']?.toString() ?? 'Unknown',
        'detected': <String>[],
      };
    }
  }

  /// Validate from ingredient list only (for Supabase recipes)
  static Map<String, dynamic> validateIngredients(List<String> ingredients) {
    final List<String> detectedNonHalal = [];
    final content = ingredients.join(' ').toLowerCase();

    for (var keyword in nonHalalKeywords) {
      // Use regex with word boundary for accurate matching
      final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
      if (regex.hasMatch(content)) {
        if (!detectedNonHalal.contains(keyword)) {
          detectedNonHalal.add(keyword);
        }
      }
    }

    if (detectedNonHalal.isNotEmpty) {
      return {
        'status': 'Non-Halal (Detected)',
        'detected': detectedNonHalal,
      };
    }

    return {
      'status': 'Halal',
      'detected': <String>[],
    };
  }
}
