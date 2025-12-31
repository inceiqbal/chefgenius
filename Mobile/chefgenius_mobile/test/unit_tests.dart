// Whitebox Unit Tests for ChefGenius
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';

// ==============================================================
// UNIT TEST 1: TranslationService - Language Detection
// ==============================================================
void main() {
  group('TranslationService Tests', () {
    // Test Indonesian language detection
    test('isLikelyIndonesian - detects Indonesian text', () {
      // Arrange
      const indonesianText = 'Ini adalah resep ayam goreng yang sangat lezat';
      
      // Act
      final result = _isLikelyIndonesian(indonesianText);
      
      // Assert
      expect(result, true);
    });

    test('isLikelyIndonesian - returns false for English text', () {
      const englishText = 'This is a delicious fried chicken recipe';
      final result = _isLikelyIndonesian(englishText);
      expect(result, false);
    });

    // Test English language detection
    test('isLikelyEnglish - detects English text', () {
      // Teks dengan banyak marker: 'this', 'is', 'the', 'for', 'you'
      const englishText = 'This is the best recipe for you and your family';
      final result = _isLikelyEnglish(englishText);
      expect(result, true);
    });

    test('isLikelyEnglish - returns false for Indonesian text', () {
      const indonesianText = 'Kucing itu melompat dengan cepat';
      final result = _isLikelyEnglish(indonesianText);
      expect(result, false);
    });

    // Test needsTranslation
    test('needsTranslation - Indonesian content needs translation for EN user', () {
      // Teks dengan banyak marker Indonesia: 'ini', 'adalah', 'yang', 'sangat', 'untuk'
      const content = 'Ini adalah resep yang sangat lezat untuk keluarga';
      const targetLang = 'en';
      final result = _needsTranslation(content, targetLang);
      expect(result, true);
    });

    test('needsTranslation - English content does not need translation for EN user', () {
      // Teks dengan marker: 'this', 'is', 'for', 'the'
      const content = 'This is the best fried rice recipe for you';
      const targetLang = 'en';
      final result = _needsTranslation(content, targetLang);
      expect(result, false);
    });
  });

  // ==============================================================
  // UNIT TEST 2: Halal Validation
  // ==============================================================
  group('Halal Validation Tests', () {
    test('validateHalalConservative - detects pork as Non-Halal', () {
      final recipe = {
        'title': 'Bacon Carbonara',
        'main_ingredients': ['pasta', 'bacon', 'egg', 'cheese'],
      };
      final result = _validateHalalConservative(recipe);
      expect(result, 'Non-Halal (Detected)');
    });

    test('validateHalalConservative - detects chicken as Halal', () {
      final recipe = {
        'title': 'Ayam Goreng',
        'main_ingredients': ['ayam', 'bawang', 'garam'],
      };
      final result = _validateHalalConservative(recipe);
      expect(result, 'Halal');
    });

    test('validateHalalConservative - detects alcohol as Non-Halal', () {
      final recipe = {
        'title': 'Red Wine Steak',
        'description': 'Steak with red wine sauce',
      };
      final result = _validateHalalConservative(recipe);
      expect(result, 'Non-Halal (Detected)');
    });

    test('validateHalalConservative - returns Unknown for ambiguous recipe', () {
      final recipe = {
        'title': 'Mystery Dish',
        'main_ingredients': ['vegetable', 'salt'],
      };
      final result = _validateHalalConservative(recipe);
      expect(result, 'Unknown');
    });
  });

  // ==============================================================
  // UNIT TEST 3: Notification Badge Count
  // ==============================================================
  group('Notification Provider Tests', () {
    test('unreadCount starts at 0', () {
      final provider = MockNotificationProvider();
      expect(provider.unreadCount, 0);
    });

    test('unreadCount updates correctly', () {
      final provider = MockNotificationProvider();
      provider.setUnreadCount(5);
      expect(provider.unreadCount, 5);
    });

    test('unreadCount resets on markAsRead', () {
      final provider = MockNotificationProvider();
      provider.setUnreadCount(10);
      provider.markAsRead();
      expect(provider.unreadCount, 0);
    });
  });

  // ==============================================================
  // UNIT TEST 4: RecipeUtils - JSON Fixing
  // ==============================================================
  group('RecipeUtils Tests', () {
    test('fixRecipeFormat - normalizes halal status true to "Halal"', () {
      final input = {'halal_status': true};
      final result = _fixRecipeFormat(input);
      expect(result['halal_status'], 'Halal');
    });

    test('fixRecipeFormat - normalizes halal status false to "Non-Halal"', () {
      final input = {'halal_status': false};
      final result = _fixRecipeFormat(input);
      expect(result['halal_status'], 'Non-Halal');
    });

    test('fixRecipeFormat - returns "Unknown" for null halal status', () {
      final input = {'halal_status': null};
      final result = _fixRecipeFormat(input);
      expect(result['halal_status'], 'Unknown');
    });

    test('fixRecipeFormat - converts steps String to List', () {
      final input = {'steps': 'Single step instruction'};
      final result = _fixRecipeFormat(input);
      expect(result['steps'], isA<List>());
      expect((result['steps'] as List).length, 1);
    });

    test('fixRecipeFormat - handles steps as Map', () {
      final input = {'steps': {'1': 'Step 1', '2': 'Step 2'}};
      final result = _fixRecipeFormat(input);
      expect(result['steps'], isA<List>());
      expect((result['steps'] as List).length, 2);
    });

    test('fixRecipeFormat - returns empty list for null steps', () {
      final input = {'steps': null};
      final result = _fixRecipeFormat(input);
      expect(result['steps'], []);
    });
  });

  // ==============================================================
  // UNIT TEST 5: IngredientMatcher - Ingredient Translation
  // ==============================================================
  group('IngredientMatcher Tests', () {
    test('normalize - translates Indonesian "telur" to "egg"', () {
      final result = _normalizeIngredient('telur');
      expect(result, 'egg');
    });

    test('normalize - translates "ayam" to "chicken"', () {
      final result = _normalizeIngredient('ayam');
      expect(result, 'chicken');
    });

    test('normalize - translates "bawang putih" to "garlic"', () {
      final result = _normalizeIngredient('bawang putih');
      expect(result, 'garlic');
    });

    test('normalize - removes quantity words like "2 buah"', () {
      final result = _normalizeIngredient('2 buah telur');
      expect(result, 'egg');
    });

    test('normalize - removes unit words like "sdm" and "gram"', () {
      final result = _normalizeIngredient('3 sdm minyak');
      expect(result, 'cooking oil');
    });

    test('normalize - returns original for unknown ingredients', () {
      final result = _normalizeIngredient('unicorn meat');
      expect(result, 'unicorn meat');
    });

    test('normalize - handles case insensitive input', () {
      final result = _normalizeIngredient('TELUR AYAM');
      expect(result, 'egg');
    });

    test('isMatch - returns true when pantry has exact ingredient', () {
      final result = _isIngredientMatch('chicken', ['chicken', 'egg', 'rice']);
      expect(result, true);
    });

    test('isMatch - returns true with Indonesian to English mapping', () {
      final result = _isIngredientMatch('ayam', ['chicken', 'egg']);
      expect(result, true);
    });

    test('isMatch - returns false when ingredient not in pantry', () {
      final result = _isIngredientMatch('beef', ['chicken', 'egg']);
      expect(result, false);
    });
  });

  // ==============================================================
  // UNIT TEST 6: Language Provider Logic
  // ==============================================================
  group('Language Provider Tests', () {
    test('getText - returns Indonesian text for key', () {
      final result = _getText('app_name', 'id');
      expect(result, isNotEmpty);
    });

    test('getText - replaces @0 placeholder with argument', () {
      final result = _getTextWithArgs('welcome_user', ['John'], 'en');
      expect(result.contains('John'), true);
    });
  });

  // ==============================================================
  // UNIT TEST 7: ShoppingListProvider Logic
  // ==============================================================
  group('ShoppingListProvider Tests', () {
    test('groupedItems - groups items by recipe title', () {
      final items = [
        MockShoppingItem('Telur', 'Nasi Goreng'),
        MockShoppingItem('Bawang', 'Nasi Goreng'),
        MockShoppingItem('Ayam', 'Ayam Bakar'),
      ];
      final grouped = _groupItems(items);
      expect(grouped.keys.length, 2);
      expect(grouped['Nasi Goreng']!.length, 2);
      expect(grouped['Ayam Bakar']!.length, 1);
    });

    test('groupedItems - empty title becomes Tambahan Lain', () {
      final items = [
        MockShoppingItem('Garam', ''),
        MockShoppingItem('Gula', ''),
      ];
      final grouped = _groupItems(items);
      expect(grouped.containsKey('Tambahan Lain'), true);
      expect(grouped['Tambahan Lain']!.length, 2);
    });

    test('detectDuplicate - finds existing item', () {
      final items = [
        MockShoppingItem('Telur', 'Nasi Goreng'),
        MockShoppingItem('Bawang', 'Nasi Goreng'),
      ];
      final isDuplicate = _isDuplicateItem(items, 'telur', 'Nasi Goreng');
      expect(isDuplicate, true);
    });

    test('detectDuplicate - case insensitive', () {
      final items = [MockShoppingItem('Telur Ayam', 'Nasi Goreng')];
      final isDuplicate = _isDuplicateItem(items, 'TELUR AYAM', 'Nasi Goreng');
      expect(isDuplicate, true);
    });

    test('detectDuplicate - different recipe returns false', () {
      final items = [MockShoppingItem('Telur', 'Nasi Goreng')];
      final isDuplicate = _isDuplicateItem(items, 'Telur', 'Ayam Bakar');
      expect(isDuplicate, false);
    });
  });

  // ==============================================================
  // UNIT TEST 8: RecipeRatingProvider Logic
  // ==============================================================
  group('RecipeRatingProvider Tests', () {
    test('getAverageRating - returns 0 for unknown recipe', () {
      final provider = MockRatingProvider();
      expect(provider.getAverageRating(999), 0.0);
    });

    test('getAverageRating - returns cached value', () {
      final provider = MockRatingProvider();
      provider.setAverageRating(1, 4.5);
      expect(provider.getAverageRating(1), 4.5);
    });

    test('getRatingCount - returns 0 for unknown recipe', () {
      final provider = MockRatingProvider();
      expect(provider.getRatingCount(999), 0);
    });

    test('validateRating - rejects rating below 1', () {
      final isValid = _isValidRating(0);
      expect(isValid, false);
    });

    test('validateRating - rejects rating above 5', () {
      final isValid = _isValidRating(6);
      expect(isValid, false);
    });

    test('validateRating - accepts rating 1-5', () {
      expect(_isValidRating(1), true);
      expect(_isValidRating(3), true);
      expect(_isValidRating(5), true);
    });

    test('calculateAverageRating - computes correctly', () {
      final ratings = [5, 4, 3, 4, 4];
      final average = _calculateAverage(ratings);
      expect(average, 4.0);
    });
  });

  // ==============================================================
  // UNIT TEST 9: ConnectivityProvider Logic
  // ==============================================================
  group('ConnectivityProvider Tests', () {
    test('isOffline - starts as false (assume online)', () {
      final provider = MockConnectivityProvider();
      expect(provider.isOffline, false);
    });

    test('updateStatus - sets offline when no connection', () {
      final provider = MockConnectivityProvider();
      provider.updateStatus(['none']);
      expect(provider.isOffline, true);
    });

    test('updateStatus - sets online when wifi available', () {
      final provider = MockConnectivityProvider();
      provider.updateStatus(['none']);
      expect(provider.isOffline, true);
      provider.updateStatus(['wifi']);
      expect(provider.isOffline, false);
    });

    test('updateStatus - sets online when mobile available', () {
      final provider = MockConnectivityProvider();
      provider.updateStatus(['mobile']);
      expect(provider.isOffline, false);
    });
  });

  // ==============================================================
  // UNIT TEST 10: Edge Cases & Additional Tests
  // ==============================================================
  group('Edge Cases Tests', () {
    // TranslationService edge cases
    test('isLikelyIndonesian - empty string returns false', () {
      expect(_isLikelyIndonesian(''), false);
    });

    test('isLikelyEnglish - empty string returns false', () {
      expect(_isLikelyEnglish(''), false);
    });

    test('needsTranslation - empty string returns false', () {
      expect(_needsTranslation('', 'en'), false);
    });

    // Halal validation edge cases
    test('validateHalal - empty recipe returns Unknown', () {
      final result = _validateHalalConservative({'title': '', 'main_ingredients': []});
      expect(result, 'Unknown');
    });

    test('validateHalal - mixed halal and haram returns Non-Halal', () {
      final result = _validateHalalConservative({
        'title': 'Mixed Dish',
        'main_ingredients': ['chicken', 'bacon'],
      });
      expect(result, 'Non-Halal (Detected)');
    });

    // IngredientMatcher edge cases
    test('normalize - handles empty string', () {
      final result = _normalizeIngredient('');
      expect(result, '');
    });

    test('normalize - handles only numbers', () {
      final result = _normalizeIngredient('123');
      expect(result, '');
    });

    test('isMatch - empty pantry returns false', () {
      final result = _isIngredientMatch('chicken', []);
      expect(result, false);
    });

    // RecipeUtils edge cases
    test('fixRecipeFormat - handles all_ingredients as Map', () {
      final input = {
        'all_ingredients': {'name': 'Telur', 'quantity': '2 butir'}
      };
      final result = _fixRecipeFormatExtended(input);
      expect(result['all_ingredients'], isA<List>());
    });

    test('fixRecipeFormat - handles main_ingredients as String', () {
      final input = {'main_ingredients': 'Ayam'};
      final result = _fixRecipeFormatExtended(input);
      expect(result['main_ingredients'], isA<List>());
      expect((result['main_ingredients'] as List).first, 'Ayam');
    });
  });
}

// ==============================================================
// HELPER FUNCTIONS (Copy dari TranslationService untuk testing)
// ==============================================================

bool _isLikelyIndonesian(String text) {
  final indonesianMarkers = [
    'yang', 'dan', 'untuk', 'dengan', 'ini', 'itu', 'adalah', 'dari',
    'ke', 'di', 'pada', 'akan', 'sudah', 'bisa', 'tidak', 'ada',
    'saya', 'kamu', 'kami', 'mereka', 'nya', 'kan', 'lah', 'pun',
    'kalau', 'jika', 'seperti', 'sangat', 'sekali', 'atau', 'tetapi'
  ];
  
  final lowerText = text.toLowerCase();
  int markerCount = 0;
  for (final marker in indonesianMarkers) {
    if (RegExp(r'\b' + marker + r'\b').hasMatch(lowerText)) {
      markerCount++;
    }
  }
  return markerCount >= 2;
}

bool _isLikelyEnglish(String text) {
  final englishMarkers = [
    'the', 'and', 'for', 'with', 'this', 'that', 'is', 'are', 'was', 'were',
    'from', 'to', 'at', 'on', 'will', 'have', 'has', 'can', 'not', 'there',
    'i', 'you', 'we', 'they', 'it', 'if', 'when', 'like', 'very', 'or', 'but'
  ];
  
  final lowerText = text.toLowerCase();
  int markerCount = 0;
  for (final marker in englishMarkers) {
    if (RegExp(r'\b' + marker + r'\b').hasMatch(lowerText)) {
      markerCount++;
    }
  }
  return markerCount >= 2;
}

bool _needsTranslation(String content, String targetLanguage) {
  if (content.trim().isEmpty) return false;
  
  final isIndonesian = _isLikelyIndonesian(content);
  final isEnglish = _isLikelyEnglish(content);
  
  if (targetLanguage == 'id') {
    return isEnglish && !isIndonesian;
  } else {
    return isIndonesian && !isEnglish;
  }
}

String _validateHalalConservative(Map<String, dynamic> item) {
  final List<String> tokens = [];

  void addToken(dynamic v) {
    if (v == null) return;
    if (v is String) {
      tokens.add(v.toLowerCase());
    } else if (v is List) {
      for (var e in v) {
        if (e != null) tokens.add(e.toString().toLowerCase());
      }
    }
  }

  addToken(item['title']);
  addToken(item['description']);
  addToken(item['main_ingredients']);

  final content = tokens.join(' ');

  final nonHalal = [
    'pork', 'babi', 'bacon', 'ham', 'lard', 'pancetta',
    'alcohol', 'wine', 'beer', 'vodka', 'whiskey', 'rum'
  ];

  for (var k in nonHalal) {
    if (content.contains(k)) return 'Non-Halal (Detected)';
  }

  final halalKnown = [
    'chicken', 'ayam', 'beef', 'sapi', 'lamb', 'domba',
    'fish', 'ikan', 'shrimp', 'udang', 'egg', 'telur', 'tofu', 'tempe'
  ];

  for (var k in halalKnown) {
    if (content.contains(k)) return 'Halal';
  }

  return 'Unknown';
}

// ==============================================================
// MOCK CLASSES
// ==============================================================

class MockNotificationProvider {
  int _unreadCount = 0;
  
  int get unreadCount => _unreadCount;
  
  void setUnreadCount(int count) {
    _unreadCount = count;
  }
  
  void markAsRead() {
    _unreadCount = 0;
  }
}

// ==============================================================
// HELPER: RecipeUtils (Copy logika dari recipe_utils.dart)
// ==============================================================

Map<String, dynamic> _fixRecipeFormat(Map<String, dynamic> json) {
  Map<String, dynamic> fixedJson = Map.from(json);

  String normalizeHalal(dynamic value) {
    if (value == null) return "Unknown";
    String s = value.toString().toLowerCase();
    if (s == 'true') return "Halal";
    if (s == 'false') return "Non-Halal";
    return value.toString();
  }

  fixedJson['halal_status'] = normalizeHalal(fixedJson['halal_status']);

  if (fixedJson['steps'] is String) {
    fixedJson['steps'] = [fixedJson['steps']];
  } else if (fixedJson['steps'] is Map) {
    fixedJson['steps'] = (fixedJson['steps'] as Map).values.map((e) => e.toString()).toList();
  } else if (fixedJson['steps'] is List) {
    fixedJson['steps'] = (fixedJson['steps'] as List).map((e) => e.toString()).toList();
  } else {
    fixedJson['steps'] = [];
  }

  return fixedJson;
}

// ==============================================================
// HELPER: IngredientMatcher (Copy logika dari ingredient_matcher.dart)
// ==============================================================

final List<String> _ignoreWords = [
  'secukupnya', 'sdm', 'sdt', 'kg', 'gr', 'g', 'gram', 'buah', 
  'siung', 'batang', 'ikat', 'lembar', 'potong', 'iris', 'liter', 
  'ml', 'gelas', 'cangkir', 'botol', 'sendok', 'makan', 'teh', 'jumbo', 'kecil', 'sedang', 'besar',
  'butir', 'pcs', 'pack', 'bungkus', 'kaleng'
];

final Map<String, String> _ingredientDictionary = {
  'telur': 'egg',
  'telur ayam': 'egg',
  'telor': 'egg',
  'egg': 'egg',
  'eggs': 'egg',
  'ayam': 'chicken',
  'daging ayam': 'chicken',
  'chicken': 'chicken',
  'bawang putih': 'garlic',
  'garlic': 'garlic',
  'bawang merah': 'shallot',
  'shallot': 'shallot',
  'minyak': 'cooking oil',
  'minyak goreng': 'cooking oil',
  'cooking oil': 'cooking oil',
  'garam': 'salt',
  'salt': 'salt',
  'beras': 'rice',
  'nasi': 'rice',
  'rice': 'rice',
  'daging sapi': 'beef',
  'beef': 'beef',
  'udang': 'shrimp',
  'shrimp': 'shrimp',
};

String _normalizeIngredient(String input) {
  String lowerInput = input.toLowerCase();
  
  // Hapus angka
  lowerInput = lowerInput.replaceAll(RegExp(r'[0-9]'), '');

  // Hapus kata-kata sampah
  for (var word in _ignoreWords) {
    lowerInput = lowerInput.replaceAll(RegExp('\\b$word\\b'), '');
  }
  
  // Hapus simbol aneh selain huruf
  lowerInput = lowerInput.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
  
  // Cek Kamus
  if (_ingredientDictionary.containsKey(lowerInput)) {
    return _ingredientDictionary[lowerInput]!;
  }
  
  // Cek partial match
  for (var key in _ingredientDictionary.keys) {
    if (lowerInput.contains(key) && key.length > 3) {
       return _ingredientDictionary[key]!;
    }
  }

  return lowerInput;
}

bool _isIngredientMatch(String recipeIngredient, List<String> pantryItems) {
  String normalized = _normalizeIngredient(recipeIngredient);
  
  for (var pantryItem in pantryItems) {
    String pantryNormalized = _normalizeIngredient(pantryItem);
    if (normalized == pantryNormalized || 
        normalized.contains(pantryNormalized) || 
        pantryNormalized.contains(normalized)) {
      return true;
    }
  }
  return false;
}

// ==============================================================
// HELPER: Language Provider (Simplified untuk testing)
// ==============================================================

final Map<String, String> _indonesianTexts = {
  'app_name': 'Chef Genius',
  'welcome_user': 'Selamat datang, @0!',
};

final Map<String, String> _englishTexts = {
  'app_name': 'Chef Genius',
  'welcome_user': 'Welcome, @0!',
};

String _getText(String key, String locale) {
  if (locale == 'id') {
    return _indonesianTexts[key] ?? _englishTexts[key] ?? key;
  } else {
    return _englishTexts[key] ?? _indonesianTexts[key] ?? key;
  }
}

String _getTextWithArgs(String key, List<String> args, String locale) {
  String text = _getText(key, locale);
  for (int i = 0; i < args.length; i++) {
    text = text.replaceAll('@$i', args[i]);
  }
  return text;
}

// ==============================================================
// HELPER: ShoppingListProvider
// ==============================================================

class MockShoppingItem {
  final String itemName;
  final String recipeTitle;
  bool isChecked;

  MockShoppingItem(this.itemName, this.recipeTitle, {this.isChecked = false});
}

Map<String, List<MockShoppingItem>> _groupItems(List<MockShoppingItem> items) {
  Map<String, List<MockShoppingItem>> groups = {};
  for (var item in items) {
    String key = item.recipeTitle.isEmpty ? 'Tambahan Lain' : item.recipeTitle;
    if (!groups.containsKey(key)) {
      groups[key] = [];
    }
    groups[key]!.add(item);
  }
  return groups;
}

bool _isDuplicateItem(List<MockShoppingItem> items, String name, String recipeTitle) {
  return items.any((existing) =>
      existing.itemName.toLowerCase() == name.toLowerCase() &&
      existing.recipeTitle == recipeTitle);
}

// ==============================================================
// HELPER: RecipeRatingProvider
// ==============================================================

class MockRatingProvider {
  final Map<int, double> _averageRatings = {};
  final Map<int, int> _ratingCounts = {};

  double getAverageRating(int recipeId) => _averageRatings[recipeId] ?? 0.0;
  int getRatingCount(int recipeId) => _ratingCounts[recipeId] ?? 0;

  void setAverageRating(int recipeId, double rating) {
    _averageRatings[recipeId] = rating;
  }

  void setRatingCount(int recipeId, int count) {
    _ratingCounts[recipeId] = count;
  }
}

bool _isValidRating(int rating) {
  return rating >= 1 && rating <= 5;
}

double _calculateAverage(List<int> ratings) {
  if (ratings.isEmpty) return 0.0;
  int sum = ratings.reduce((a, b) => a + b);
  return sum / ratings.length;
}

// ==============================================================
// HELPER: ConnectivityProvider
// ==============================================================

class MockConnectivityProvider {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  void updateStatus(List<String> results) {
    if (results.contains('none')) {
      _isOffline = true;
    } else {
      _isOffline = false;
    }
  }
}

// ==============================================================
// HELPER: Extended RecipeUtils
// ==============================================================

Map<String, dynamic> _fixRecipeFormatExtended(Map<String, dynamic> json) {
  Map<String, dynamic> fixedJson = Map.from(json);

  // Handle all_ingredients
  if (fixedJson['all_ingredients'] is Map) {
    final map = fixedJson['all_ingredients'] as Map;
    if (map.containsKey('name') || map.containsKey('quantity')) {
      fixedJson['all_ingredients'] = [map];
    } else {
      fixedJson['all_ingredients'] = map.values.toList();
    }
  } else if (fixedJson['all_ingredients'] == null) {
    fixedJson['all_ingredients'] = [];
  }

  // Handle main_ingredients
  if (fixedJson['main_ingredients'] is String) {
    fixedJson['main_ingredients'] = [fixedJson['main_ingredients']];
  } else if (fixedJson['main_ingredients'] is Map) {
    fixedJson['main_ingredients'] = (fixedJson['main_ingredients'] as Map)
        .values
        .map((e) => e.toString())
        .toList();
  } else if (fixedJson['main_ingredients'] is List) {
    fixedJson['main_ingredients'] = (fixedJson['main_ingredients'] as List)
        .map((e) => e.toString())
        .toList();
  }

  return fixedJson;
}
