class QuantityParser {
  // Parse quantity string into value and unit
  // Examples:
  // "100 gram" -> {value: 100.0, unit: "gram"}
  // "1/2 sdm" -> {value: 0.5, unit: "sdm"}
  // "2 butir" -> {value: 2.0, unit: "butir"}
  // "secukupnya" -> {value: 0.0, unit: "secukupnya"}
  // "" -> {value: 0.0, unit: ""}
  
  static Map<String, dynamic> parse(String input) {
    if (input.isEmpty) {
      return {'value': 0.0, 'unit': ''};
    }

    String cleaned = input.trim().toLowerCase();
    
    // Special case: secukupnya
    if (cleaned.contains('secukupnya') || cleaned.contains('to taste')) {
      return {'value': 0.0, 'unit': 'secukupnya'};
    }

    // Extract number (including fractions)
    double value = 0.0;
    String unit = '';

    // Try to find fraction pattern (e.g., "1/2", "1 1/2")
    final fractionRegex = RegExp(r'(\d+)\s*/\s*(\d+)');
    final mixedFractionRegex = RegExp(r'(\d+)\s+(\d+)\s*/\s*(\d+)');
    
    // Check for mixed fraction (e.g., "1 1/2")
    final mixedMatch = mixedFractionRegex.firstMatch(cleaned);
    if (mixedMatch != null) {
      int whole = int.parse(mixedMatch.group(1)!);
      int numerator = int.parse(mixedMatch.group(2)!);
      int denominator = int.parse(mixedMatch.group(3)!);
      value = whole + (numerator / denominator);
      // Remove matched part to get unit
      cleaned = cleaned.replaceFirst(mixedMatch.group(0)!, '').trim();
    } else {
      // Check for simple fraction (e.g., "1/2")
      final fractionMatch = fractionRegex.firstMatch(cleaned);
      if (fractionMatch != null) {
        int numerator = int.parse(fractionMatch.group(1)!);
        int denominator = int.parse(fractionMatch.group(2)!);
        value = numerator / denominator;
        // Remove matched part to get unit
        cleaned = cleaned.replaceFirst(fractionMatch.group(0)!, '').trim();
      } else {
        // Try to extract decimal/integer number
        final numberRegex = RegExp(r'(\d+\.?\d*)');
        final numberMatch = numberRegex.firstMatch(cleaned);
        if (numberMatch != null) {
          value = double.tryParse(numberMatch.group(1)!) ?? 0.0;
          // Remove matched part to get unit
          cleaned = cleaned.replaceFirst(numberMatch.group(0)!, '').trim();
        }
      }
    }

    // Extract unit from remaining string
    unit = cleaned
        .replaceAll(RegExp(r'[^a-z\s]'), '') // Remove non-letter chars
        .trim();

    // Normalize common unit variations
    unit = _normalizeUnit(unit);

    return {'value': value, 'unit': unit};
  }

  // Normalize unit to standard form
  static String _normalizeUnit(String unit) {
    unit = unit.toLowerCase().trim();
    
    // Weight units
    if (unit.contains('gram') || unit == 'g' || unit == 'gr') return 'gram';
    if (unit.contains('kilogram') || unit == 'kg') return 'kg';
    
    // Volume units
    if (unit.contains('liter') || unit == 'l') return 'liter';
    if (unit.contains('mililiter') || unit == 'ml') return 'ml';
    if (unit.contains('sendok makan') || unit == 'sdm' || unit.contains('tablespoon') || unit == 'tbsp') return 'sdm';
    if (unit.contains('sendok teh') || unit == 'sdt' || unit.contains('teaspoon') || unit == 'tsp') return 'sdt';
    if (unit.contains('gelas') || unit.contains('cup')) return 'gelas';
    if (unit.contains('cangkir')) return 'cangkir';
    
    // Count units
    if (unit.contains('butir') || unit.contains('biji')) return 'butir';
    if (unit.contains('buah') || unit.contains('pcs') || unit.contains('piece')) return 'buah';
    if (unit.contains('siung') || unit.contains('clove')) return 'siung';
    if (unit.contains('batang') || unit.contains('stick')) return 'batang';
    if (unit.contains('ikat') || unit.contains('bunch')) return 'ikat';
    if (unit.contains('lembar') || unit.contains('sheet') || unit.contains('slice')) return 'lembar';
    
    return unit;
  }

  // Convert quantity to base unit (e.g., kg -> gram, liter -> ml)
  static Map<String, dynamic> toBaseUnit(Map<String, dynamic> parsed) {
    double value = parsed['value'];
    String unit = parsed['unit'];

    // Weight: Convert to grams
    if (unit == 'kg') {
      return {'value': value * 1000, 'unit': 'gram'};
    }
    
    // Volume: Convert to ml
    if (unit == 'liter') {
      return {'value': value * 1000, 'unit': 'ml'};
    }
    if (unit == 'sdm') {
      return {'value': value * 15, 'unit': 'ml'};
    }
    if (unit == 'sdt') {
      return {'value': value * 5, 'unit': 'ml'};
    }
    if (unit == 'gelas') {
      return {'value': value * 250, 'unit': 'ml'};
    }
    if (unit == 'cangkir') {
      return {'value': value * 240, 'unit': 'ml'};
    }

    // Already in base unit or count unit (no conversion)
    return parsed;
  }

  // Compare two quantities
  // Returns: 'sufficient', 'insufficient', 'unknown', 'nameOnly'
  static String compare(String pantryQty, String recipeQty) {
    // Parse both quantities
    final pantryParsed = parse(pantryQty);
    final recipeParsed = parse(recipeQty);

    // If recipe says "secukupnya", always sufficient
    if (recipeParsed['unit'] == 'secukupnya') {
      return 'sufficient';
    }

    // If both have no quantity, match by name only
    if (pantryParsed['unit'] == '' && recipeParsed['unit'] == '') {
      return 'nameOnly';
    }

    // If only one has quantity, cannot compare
    if (pantryParsed['unit'] == '' || recipeParsed['unit'] == '') {
      return 'unknown';
    }

    // Convert both to base units
    final pantryBase = toBaseUnit(pantryParsed);
    final recipeBase = toBaseUnit(recipeParsed);

    // Check if units are compatible (same base unit)
    if (pantryBase['unit'] != recipeBase['unit']) {
      return 'unknown'; // Cannot compare different unit types (gram vs butir)
    }

    // Compare values
    double pantryValue = pantryBase['value'];
    double recipeValue = recipeBase['value'];

    if (pantryValue >= recipeValue) {
      return 'sufficient';
    } else {
      return 'insufficient';
    }
  }
}

// Enum for quantity comparison status
enum QuantityStatus {
  sufficient,   // Pantry >= Recipe (Green)
  insufficient, // Pantry < Recipe (Yellow)
  unknown,      // Cannot compare (Yellow)
  nameOnly      // Both have no quantity (Current behavior - Green if name matches)
}
