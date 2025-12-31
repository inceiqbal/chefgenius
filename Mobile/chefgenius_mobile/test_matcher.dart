
void main() {
  final pantryItems = ["Telur", "Mentega"];
  
  test("1 butir telur", pantryItems, "full");
  test("1 telur, mentega", pantryItems, "full");
  test("1 telur, tepung", pantryItems, "partial");
  test("Mentega atau Minyak", pantryItems, "full");
  test("Minyak atau Mentega", pantryItems, "full");
  test("Garam", pantryItems, "missing");
  test("Telur dan Tepung", pantryItems, "partial");
}

void test(String recipeLine, List<String> pantryItems, String expected) {
  final status = IngredientMatcher.checkStatus(recipeLine, pantryItems);
  final statusStr = status.toString().split('.').last;
  if (statusStr == expected) {
    print("PASS: '$recipeLine' -> $statusStr");
  } else {
    print("FAIL: '$recipeLine' -> Expected $expected, got $statusStr");
  }
}

class IngredientMatcher {
  static final List<String> _ignoreWords = [
    'secukupnya', 'sdm', 'sdt', 'kg', 'gr', 'g', 'gram', 'buah', 
    'siung', 'batang', 'ikat', 'lembar', 'potong', 'iris', 'liter', 
    'ml', 'gelas', 'cangkir', 'botol', 'sendok', 'makan', 'teh', 'jumbo', 'kecil', 'sedang', 'besar',
    'butir', 'pcs', 'pack', 'bungkus', 'kaleng'
  ];

  static final Map<String, String> _ingredientDictionary = {
    'telur': 'egg',
    'telur ayam': 'egg',
    'mentega': 'butter',
    'minyak': 'oil',
    'tepung': 'flour',
    'garam': 'salt',
  };

  static IngredientMatchStatus checkStatus(String recipeLine, List<String> pantryItems) {
    List<String> components = recipeLine.split(RegExp(r'[,&]|\bdan\b'));

    int foundCount = 0;
    int validComponents = 0;

    for (var component in components) {
      List<String> orComponents = component.split(RegExp(r'\batau\b|\bor\b'));
      bool componentMatched = false;
      bool isValidComponent = false;

      for (var orComponent in orComponents) {
        String cleanComponent = normalize(orComponent);
        if (cleanComponent.length < 2) continue; 
        
        isValidComponent = true;

        bool isFound = pantryItems.any((pantryItem) {
          String pClean = normalize(pantryItem);
          return cleanComponent.contains(pClean) || pClean.contains(cleanComponent);
        });

        if (isFound) {
          componentMatched = true;
          break; 
        }
      }

      if (isValidComponent) {
        validComponents++;
        if (componentMatched) {
          foundCount++;
        }
      }
    }

    if (validComponents == 0) return IngredientMatchStatus.missing; 
    
    if (foundCount == validComponents) {
      return IngredientMatchStatus.full; 
    } else if (foundCount > 0) {
      return IngredientMatchStatus.partial; 
    } else {
      return IngredientMatchStatus.missing; 
    }
  }

  static List<String>? _cachedSortedKeys;
  static List<String> get _sortedKeys {
    if (_cachedSortedKeys == null) {
      _cachedSortedKeys = _ingredientDictionary.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
    }
    return _cachedSortedKeys!;
  }

  static String normalize(String input) {
    String lowerInput = input.toLowerCase();
    lowerInput = lowerInput.replaceAll(RegExp(r'[0-9]'), '');
    for (var word in _ignoreWords) {
      lowerInput = lowerInput.replaceAll(RegExp('\\b$word\\b'), '');
    }
    lowerInput = lowerInput.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    
    if (_ingredientDictionary.containsKey(lowerInput)) {
      return _ingredientDictionary[lowerInput]!;
    }
    
    for (var key in _sortedKeys) {
      if (lowerInput.contains(key) && key.length > 3) { 
         return _ingredientDictionary[key]!;
      }
    }

    return lowerInput;
  }
}

enum IngredientMatchStatus {
  full,    
  partial, 
  missing  
}
