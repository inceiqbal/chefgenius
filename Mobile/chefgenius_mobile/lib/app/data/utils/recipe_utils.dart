class RecipeUtils {
  // Fungsi Pawang JSON dipindah ke sini biar rapi
  static Map<String, dynamic> fixRecipeFormat(Map<String, dynamic> json) {
    Map<String, dynamic> fixedJson = Map.from(json);

    String? forceString(dynamic value) {
      if (value == null) return null;
      return value.toString(); 
    }

    // --- LOGIKA BARU: NORMALISASI HALAL ---
    // Biar gak ada tulisan "true" atau "false" yang nongol di UI
    String normalizeHalal(dynamic value) {
      if (value == null) return "Unknown";
      String s = value.toString().toLowerCase();
      if (s == 'true') return "Halal";
      if (s == 'false') return "Non-Halal";
      return value.toString(); // Balikin aslinya kalo udah bener (misal: "Halal")
    }
    // --------------------------------------

    fixedJson['title'] = forceString(fixedJson['title']);
    fixedJson['description'] = forceString(fixedJson['description']);
    fixedJson['duration'] = forceString(fixedJson['duration']);
    fixedJson['servings'] = forceString(fixedJson['servings']); 
    
    // Pake normalisasi di sini
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
    
    if (fixedJson['all_ingredients'] is List) {
      fixedJson['all_ingredients'] = (fixedJson['all_ingredients'] as List).map((e) {
        if (e is Map) {
           Map<String, dynamic> ing = Map.from(e);
           ing['name'] = forceString(ing['name']) ?? '';
           ing['quantity'] = forceString(ing['quantity']) ?? ''; 
           return ing;
        }
        return e;
      }).toList();
    }

    if (fixedJson['main_ingredients'] is String) {
      fixedJson['main_ingredients'] = [fixedJson['main_ingredients']];
    } else if (fixedJson['main_ingredients'] is Map) {
      fixedJson['main_ingredients'] = (fixedJson['main_ingredients'] as Map).values.map((e) => e.toString()).toList();
    } else if (fixedJson['main_ingredients'] is List) {
       fixedJson['main_ingredients'] = (fixedJson['main_ingredients'] as List).map((e) => e.toString()).toList();
    }

    return fixedJson;
  }
}