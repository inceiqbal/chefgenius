class IngredientMatcher {
  // --- 1. DAFTAR KATA SAMPAH (Takaran & Satuan) ---
  // Kita hapus kata-kata ini biar pencarian fokus ke nama bahannya aja
  static final List<String> _ignoreWords = [
    'secukupnya', 'sdm', 'sdt', 'kg', 'gr', 'g', 'gram', 'buah', 
    'siung', 'batang', 'ikat', 'lembar', 'potong', 'iris', 'liter', 
    'ml', 'gelas', 'cangkir', 'botol', 'sendok', 'makan', 'teh', 'jumbo', 'kecil', 'sedang', 'besar',
    'butir', 'pcs', 'pack', 'bungkus', 'kaleng'
  ];

  // --- 2. KAMUS BAHAN (THE HOLY GRAIL) ---
  static final Map<String, String> _ingredientDictionary = {
    // --- A. Bahan Pokok (Karbohidrat) ---
    'beras': 'rice',
    'bacon': 'bacon',
    'beras putih': 'rice',
    'nasi': 'rice',
    'rice': 'rice',
    'white rice': 'rice',
    'brown rice': 'brown rice',
    'beras merah': 'red rice',
    'red rice': 'red rice',
    'beras ketan': 'sticky rice',
    'beras ketan putih': 'sticky rice',
    'sticky rice': 'sticky rice',
    'tepung': 'flour',
    'tepung terigu': 'flour',
    'flour': 'flour',
    'terigu': 'flour',
    'tepung maizena': 'corn starch',
    'maizena': 'corn starch',
    'corn starch': 'corn starch',
    'tepung tapioka': 'tapioca',
    'tapioka': 'tapioca',
    'tepung sagu': 'sago',
    'sagu': 'sago',
    'kentang': 'potato',
    'potato': 'potato',
    'potatoes': 'potato',
    'ubi jalar': 'sweet potato',
    'sweet potato': 'sweet potato',
    'ubi': 'sweet potato',
    'singkong': 'cassava',
    'cassava': 'cassava',
    'roti': 'bread',
    'roti tawar': 'bread',
    'bread': 'bread',
    'pasta': 'pasta',
    'spaghetti': 'spaghetti',
    'pasta spaghetti': 'spaghetti',
    'makaroni': 'macaroni',
    'macaroni': 'macaroni',
    'pasta macaroni': 'macaroni',

    // --- B. Daging & Produk Hewani ---
    'daging sapi': 'beef',
    'daging': 'beef', 
    'beef': 'beef',
    'ground beef': 'beef',
    'minced beef': 'beef',
    'daging kambing': 'goat meat',
    'kambing': 'goat meat',
    'goat meat': 'goat meat',
    'daging ayam': 'chicken',
    'ayam': 'chicken',
    'chicken': 'chicken',
    'chicken breast': 'chicken',
    'chicken thigh': 'chicken',
    'chicken wings': 'chicken',
    'minced chicken': 'chicken',
    'daging bebek': 'duck',
    'bebek': 'duck',
    'duck': 'duck',
    'daging babi': 'pork',
    'babi': 'pork',
    'pork': 'pork',
    'hati ayam': 'chicken liver',
    'ati ayam': 'chicken liver',
    'chicken liver': 'chicken liver',
    'hati sapi': 'beef liver',
    'beef liver': 'beef liver',
    'ampela ayam': 'gizzard',
    'ampela': 'gizzard',
    'babat sapi': 'tripe',
    'babat': 'tripe',
    'telur': 'egg',
    'telur ayam': 'egg',
    'telor': 'egg',
    'egg': 'egg',
    'eggs': 'egg',
    'telur bebek': 'duck egg',
    'duck egg': 'duck egg',
    'telur puyuh': 'quail egg',
    'puyuh': 'quail egg',
    'quail egg': 'quail egg',
    'sosis': 'sausage',
    'sausage': 'sausage',
    'sosis sapi': 'beef sausage',
    'beef sausage': 'beef sausage',
    'sosis ayam': 'chicken sausage',
    'chicken sausage': 'chicken sausage',
    'nugget': 'nugget',
    'nugget ayam': 'nugget',
    'kornet': 'corned beef',
    'corned beef': 'corned beef',

    // --- C. Ikan & Seafood ---
    'ikan': 'fish',
    'fish': 'fish',
    'ikan tuna': 'tuna',
    'tuna': 'tuna',
    'ikan salmon': 'salmon',
    'salmon': 'salmon',
    'ikan tongkol': 'mackerel tuna',
    'tongkol': 'mackerel tuna',
    'ikan kembung': 'mackerel',
    'kembung': 'mackerel',
    'ikan bandeng': 'milkfish',
    'bandeng': 'milkfish',
    'ikan kakap': 'snapper',
    'ikan kakap merah': 'red snapper',
    'red snapper': 'red snapper',
    'ikan tenggiri': 'spanish mackerel',
    'tenggiri': 'spanish mackerel',
    'ikan nila': 'tilapia',
    'nila': 'tilapia',
    'ikan gurame': 'gourami',
    'gurame': 'gourami',
    'ikan lele': 'catfish',
    'lele': 'catfish',
    'catfish': 'catfish',
    'udang': 'shrimp',
    'shrimp': 'shrimp',
    'prawn': 'shrimp',
    'cumi': 'squid',
    'cumi-cumi': 'squid',
    'squid': 'squid',
    'sotong': 'cuttlefish',
    'cuttlefish': 'cuttlefish',
    'gurita': 'octopus',
    'octopus': 'octopus',
    'kerang': 'clam',
    'clam': 'clam',
    'kerang hijau': 'green mussel',
    'kerang dara': 'blood clam',
    'tiram': 'oyster',
    'oyster': 'oyster',
    'kepiting': 'crab',
    'crab': 'crab',
    'lobster': 'lobster',
    'ikan asin': 'salted fish',
    'salted fish': 'salted fish',
    'terasi': 'shrimp paste',
    'shrimp paste': 'shrimp paste',

    // --- D. Sayuran Hijau ---
    'bayam': 'spinach',
    'spinach': 'spinach',
    'sawi': 'mustard greens',
    'sawi hijau': 'mustard greens',
    'sawi putih': 'napa cabbage',
    'napa cabbage': 'napa cabbage',
    'pakcoy': 'bok choy',
    'pak choy': 'bok choy',
    'bok choy': 'bok choy',
    'kangkung': 'water spinach',
    'water spinach': 'water spinach',
    'selada': 'lettuce',
    'lettuce': 'lettuce',
    'daun selada': 'lettuce', // Tambahan biar match kasus kamu
    'kale': 'kale',
    'brokoli': 'broccoli',
    'broccoli': 'broccoli',
    'kembang kol': 'cauliflower',
    'cauliflower': 'cauliflower',
    'kubis': 'cabbage',
    'kubis hijau': 'cabbage',
    'cabbage': 'cabbage',
    'daun bawang': 'spring onion',
    'spring onion': 'spring onion',
    'bawang prei': 'leek',
    'leek': 'leek',
    'seledri': 'celery',
    'daun seledri': 'celery',
    'celery': 'celery',
    'daun ketumbar': 'coriander',
    'ketumbar': 'coriander',
    'coriander': 'coriander',
    'cilantro': 'coriander',
    'daun basil': 'basil',
    'basil': 'basil',
    'daun mint': 'mint',
    'mint': 'mint',

    // --- E. Sayuran Buah ---
    'tomat': 'tomato',
    'tomato': 'tomato',
    'tomat cherry': 'cherry tomato',
    'cherry tomato': 'cherry tomato',
    'paprika': 'bell pepper',
    'bell pepper': 'bell pepper',
    'paprika merah': 'red bell pepper',
    'paprika hijau': 'green bell pepper',
    'paprika kuning': 'yellow bell pepper',
    'cabai': 'chili',
    'cabe': 'chili',
    'chili': 'chili',
    'chilli': 'chili',
    'cabai rawit': 'bird eye chili',
    'cabe rawit': 'bird eye chili',
    'cabai merah': 'red chili',
    'cabai merah besar': 'red chili',
    'cabe merah': 'red chili',
    'cabai hijau': 'green chili',
    'terung': 'eggplant',
    'terong': 'eggplant',
    'terung ungu': 'eggplant',
    'eggplant': 'eggplant',
    'mentimun': 'cucumber',
    'timun': 'cucumber',
    'cucumber': 'cucumber',
    'labu siam': 'chayote',
    'chayote': 'chayote',
    'labu': 'pumpkin',
    'labu kuning': 'pumpkin',
    'pumpkin': 'pumpkin',
    'pare': 'bitter melon',
    'bitter melon': 'bitter melon',
    'buncis': 'green beans',
    'green beans': 'green beans',
    'kacang panjang': 'long beans',
    'long beans': 'long beans',
    'jagung': 'corn',
    'jagung manis': 'corn',
    'corn': 'corn',

    // --- F. Umbi & Akar ---
    'wortel': 'carrot',
    'carrot': 'carrot',
    'lobak': 'radish',
    'radish': 'radish',
    'jahe': 'ginger',
    'ginger': 'ginger',
    'kunyit': 'turmeric',
    'turmeric': 'turmeric',
    'lengkuas': 'galangal',
    'laos': 'galangal',
    'galangal': 'galangal',
    'kencur': 'kencur',

    // --- G. Bawang-bawangan ---
    'bawang putih': 'garlic',
    'baput': 'garlic',
    'garlic': 'garlic',
    'bawang merah': 'shallot',
    'bamer': 'shallot',
    'shallot': 'shallot',
    'bawang bombay': 'onion',
    'bombay': 'onion',
    'onion': 'onion',

    // --- H. Kacang-kacangan ---
    'kacang': 'peanut', 
    'kacang tanah': 'peanut',
    'peanut': 'peanut',
    'kacang kedelai': 'soybean',
    'kedelai': 'soybean',
    'soybean': 'soybean',
    'kacang hijau': 'mung bean',
    'mung bean': 'mung bean',
    'kacang merah': 'red bean',
    'red bean': 'red bean',
    'almond': 'almond',
    'kacang almond': 'almond',
    'mete': 'cashew',
    'kacang mete': 'cashew',
    'cashew': 'cashew',
    'edamame': 'edamame',

    // --- K. Bahan Fermentasi & Penyedap ---
    'kecap': 'sweet soy sauce', 
    'kecap manis': 'sweet soy sauce',
    'sweet soy sauce': 'sweet soy sauce',
    'kecap asin': 'soy sauce',
    'soy sauce': 'soy sauce',
    'saus tiram': 'oyster sauce',
    'oyster sauce': 'oyster sauce',
    'saus ikan': 'fish sauce',
    'fish sauce': 'fish sauce',
    'saus tomat': 'tomato sauce',
    'tomato sauce': 'tomato sauce',
    'ketchup': 'tomato sauce',
    'saus sambal': 'chili sauce',
    'sambal': 'chili sauce',
    'chili sauce': 'chili sauce',
    'mayonnaise': 'mayonnaise',
    'mayo': 'mayonnaise',
    'mustard': 'mustard',
    'gochujang': 'gochujang',
    'tauco': 'tauco',
    'miso': 'miso',
    'kimchi': 'kimchi',
    'tempe': 'tempeh',
    'tempeh': 'tempeh',
    'tahu': 'tofu',
    'tahu putih': 'tofu',
    'tofu': 'tofu',
    'tahu kuning': 'yellow tofu',
    'tahu sutra': 'silken tofu',
    'silken tofu': 'silken tofu',
    'yogurt': 'yogurt',
    'yogurt tawar': 'yogurt',
    'greek yogurt': 'greek yogurt',
    'yogurt greek': 'greek yogurt',

    // --- L. Minyak & Lemak ---
    'minyak': 'cooking oil',
    'minyak goreng': 'cooking oil',
    'cooking oil': 'cooking oil',
    'minyak zaitun': 'olive oil',
    'olive oil': 'olive oil',
    'minyak kelapa': 'coconut oil',
    'coconut oil': 'coconut oil',
    'minyak wijen': 'sesame oil',
    'sesame oil': 'sesame oil',
    'mentega': 'butter',
    'butter': 'butter',
    'margarin': 'margarine',
    'margarine': 'margarine',

    // --- M. Bahan Pemanis ---
    'gula': 'sugar',
    'gula pasir': 'sugar',
    'sugar': 'sugar',
    'gula merah': 'palm sugar',
    'gula aren': 'palm sugar',
    'gula jawa': 'palm sugar',
    'palm sugar': 'palm sugar',
    'brown sugar': 'brown sugar',
    'madu': 'honey',
    'honey': 'honey',

    // --- N. Produk Susu ---
    'susu': 'milk',
    'susu cair': 'milk',
    'milk': 'milk',
    'susu kental manis': 'condensed milk',
    'skm': 'condensed milk',
    'kental manis': 'condensed milk',
    'condensed milk': 'condensed milk',
    'keju': 'cheese',
    'cheese': 'cheese',
    'keju cheddar': 'cheddar',
    'cheddar': 'cheddar',
    'keju mozzarella': 'mozzarella',
    'mozzarella': 'mozzarella',
    'keju parmesan': 'parmesan',
    'parmesan': 'parmesan',

    // --- P. Bahan Kaldu & Olahan ---
    'santan': 'coconut milk',
    'santan cair': 'coconut milk',
    'santan kental': 'coconut milk',
    'coconut milk': 'coconut milk',
    'kaldu ayam': 'chicken stock',
    'chicken stock': 'chicken stock',
    'kaldu sapi': 'beef stock',
    'beef stock': 'beef stock',
    'kaldu sayur': 'vegetable stock',
    'vegetable stock': 'vegetable stock',

    // --- J. Bumbu & Rempah Kering ---
    'garam': 'salt',
    'salt': 'salt',
    'lada': 'pepper',
    'merica': 'pepper',
    'pepper': 'pepper',
    'lada hitam': 'black pepper',
    'black pepper': 'black pepper',
    'lada putih': 'white pepper',
    'white pepper': 'white pepper',
    'ketumbar bubuk': 'coriander powder',
    'coriander powder': 'coriander powder',
    'kayu manis': 'cinnamon',
    'cinnamon': 'cinnamon',
    'cengkih': 'clove',
    'clove': 'clove',
    'pala': 'nutmeg',
    'nutmeg': 'nutmeg',

    // --- R. Bahan Asia Lainnya ---
    'tauge': 'bean sprout',
    'bean sprout': 'bean sprout',
    'jengkol': 'jengkol',
    'petai': 'petai',
    'pete': 'petai',

    // --- U. Minuman & Cairan Masak ---
    'cuka': 'vinegar',
    'cuka putih': 'vinegar',
    'vinegar': 'vinegar',
    'air': 'water',
    'water': 'water',
    'kopi': 'coffee',
    'coffee': 'coffee',
    'teh': 'tea',
    'tea': 'tea',
    'teh hitam': 'black tea',
    'black tea': 'black tea',
    'teh hijau': 'green tea',
    'green tea': 'green tea',

    // --- V. Lain-lain ---
    'bihun': 'rice vermicelli',
    'rice vermicelli': 'rice vermicelli',
    'kwetiau': 'flat noodles',
    'mie': 'noodle',
    'mi': 'noodle',
    'mie telur': 'egg noodle',
    'egg noodle': 'egg noodle',
    'noodle': 'noodle',
    'sambal matah': 'sambal matah',
    'sambal terasi': 'sambal terasi',
    'susu kedelai': 'soy milk',
    'soy milk': 'soy milk',
    'susu almond': 'almond milk',
    'almond milk': 'almond milk',
    'jamur': 'mushroom',
    'mushroom': 'mushroom',
    'jamur kancing': 'button mushroom',
    'jamur tiram': 'oyster mushroom',
    'oyster mushroom': 'oyster mushroom',
    'jamur enoki': 'enoki mushroom',
    'enoki': 'enoki mushroom',
    'jamur shitake': 'shiitake mushroom',
    'shitake': 'shiitake mushroom',
    'jamur kuping': 'wood ear mushroom',
    'daun salam': 'bay leaf',
    'bay leaf': 'bay leaf',
    'serai': 'lemongrass',
    'sereh': 'lemongrass',
    'lemongrass': 'lemongrass',
    'daun jeruk': 'lime leaf',
    'lime leaf': 'lime leaf',
    'biji wijen': 'sesame seed',
    'sesame seed': 'sesame seed',
  };

  // --- FUNGSI UTAMA BARU: Check Status (Full, Partial, Missing) ---
  // Ini logika yang mecah "Bahan A, Bahan B, Bahan C" jadi cek satu-satu
  static IngredientMatchStatus checkStatus(String recipeLine, List<String> pantryItems) {
    // print("DEBUG: Checking '$recipeLine' against pantry: $pantryItems");
    // 1. Pecah kalimat berdasarkan tanda baca pemisah (koma, &, atau kata 'dan')
    // Contoh: "Secukupnya Daun Selada, Tomat, Bawang Bombay" -> ["Secukupnya Daun Selada", " Tomat", " Bawang Bombay"]
    List<String> components = recipeLine.split(RegExp(r'[,&]|\bdan\b'));

    int foundCount = 0;
    int validComponents = 0;

    // 2. Cek setiap pecahan bahan
    for (var component in components) {
      // Cek logika ATAU (OR)
      // Contoh: "Mentega atau Minyak" -> Cukup punya salah satu
      List<String> orComponents = component.split(RegExp(r'\batau\b|\bor\b'));
      bool componentMatched = false;
      bool isValidComponent = false;

      for (var orComponent in orComponents) {
        // Bersihkan dulu (buang "Secukupnya", "2 buah", dll) lalu Normalisasi pakai Kamus
        String cleanComponent = normalize(orComponent);
        // print("DEBUG: Component '$orComponent' -> Clean: '$cleanComponent'");
        
        // Kalau setelah dibersihin ternyata kosong (misal cuma spasi atau kata "dan"), skip aja
        if (cleanComponent.length < 2) continue; 
        
        isValidComponent = true;

        // Cek apakah bahan ini ada di pantry (pake logika contains dua arah)
        bool isFound = pantryItems.any((pantryItem) {
          String pClean = normalize(pantryItem);
          // print("DEBUG: Comparing '$cleanComponent' with Pantry '$pantryItem' -> Clean: '$pClean'");
          
          // Logic: Saling mengandung (Partial Match)
          // Misal Pantry: "Bawang", Resep: "Bawang Bombay" -> Match
          // Misal Pantry: "Telur Ayam", Resep: "Telur" -> Match
          return cleanComponent.contains(pClean) || pClean.contains(cleanComponent);
        });

        if (isFound) {
          // print("DEBUG: MATCH FOUND!");
          componentMatched = true;
          break; // Kalau salah satu opsi ATAU ketemu, anggap komponen ini terpenuhi
        }
      }

      if (isValidComponent) {
        validComponents++;
        if (componentMatched) {
          foundCount++;
        }
      }
    }

    // 3. Tentukan Hasil Akhir Status
    if (validComponents == 0) return IngredientMatchStatus.missing; 
    
    if (foundCount == validComponents) {
      return IngredientMatchStatus.full; // Punya SEMUA bahan di baris ini (Hijau)
    } else if (foundCount > 0) {
      return IngredientMatchStatus.partial; // Punya SEBAGIAN (Kuning) -> Kasus "Cuma punya Selada"
    } else {
      return IngredientMatchStatus.missing; // Gak punya sama sekali (Merah)
    }
  }

  // --- FUNGSI PEMBANTU: Normalize 
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
    
    // 1. Hapus angka (takaran)
    lowerInput = lowerInput.replaceAll(RegExp(r'[0-9]'), '');

    // 2. Hapus kata-kata sampah (takaran/satuan)
    for (var word in _ignoreWords) {
      // \b artinya batas kata, biar "gram" kehapus tapi "program" enggak (eh program bukan makanan deng xD)
      lowerInput = lowerInput.replaceAll(RegExp('\\b$word\\b'), '');
    }
    
    // 3. Hapus simbol aneh selain huruf
    lowerInput = lowerInput.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    
    // 4. Cek Kamus (Translate ke English Common Name)
    if (_ingredientDictionary.containsKey(lowerInput)) {
      return _ingredientDictionary[lowerInput]!;
    }
    
    // Gunakan keys yang sudah diurutkan dari yang terpanjang
    for (var key in _sortedKeys) {
      if (lowerInput.contains(key) && key.length > 3) { // >3 biar gak match kata pendek kayak "mi" sembarangan
         return _ingredientDictionary[key]!;
      }
    }

    return lowerInput;
  }
  

  static bool isMatch(String recipeIngredient, List<String> pantryItems) {
     IngredientMatchStatus status = checkStatus(recipeIngredient, pantryItems);
     
     // HANYA return true kalau STATUSNYA FULL
     return status == IngredientMatchStatus.full;
  }
}

// --- ENUM STATUS ---
enum IngredientMatchStatus {
  full,    // Lengkap (Hijau)
  partial, // Sebagian (Kuning/Oranye)
  missing  // Tidak Ada (Merah)
}