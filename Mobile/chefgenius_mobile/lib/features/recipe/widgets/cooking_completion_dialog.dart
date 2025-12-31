import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // WAJIB: Buat simpan ke cloud
import 'package:provider/provider.dart'; // WAJIB: Buat bahasa
import '../../../../app/config/chef_cei_assets.dart'; 
import '../../../../app/data/providers/language_provider.dart'; // WAJIB: Buat translate

class CookingCompletionDialog extends StatefulWidget {
  final VoidCallback onClose;

  const CookingCompletionDialog({super.key, required this.onClose});

  @override
  State<CookingCompletionDialog> createState() => _CookingCompletionDialogState();
}

class _CookingCompletionDialogState extends State<CookingCompletionDialog> {
  final int _xpGained = 50; // XP yang didapat
  int _currentTotalXp = 0;
  int _currentLevel = 0;
  bool _isLoading = true;
  static const int xpPerLevel = 300; 
  
  final supabase = Supabase.instance.client; // Instance Supabase

  @override
  void initState() {
    super.initState();
    _processXpUpdate(); // Jalankan update XP begitu dialog muncul
  }

  // --- FUNGSI SAKTI: UPDATE XP KE CLOUD & LOKAL ---
  Future<void> _processXpUpdate() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Ambil XP terakhir dari lokal dulu sebagai cadangan
      int currentXp = prefs.getInt('user_xp') ?? 0;
      
      // 2. Coba ambil data fresh dari server Supabase biar akurat
      if (userId != null) {
        try {
          final profileData = await supabase
              .from('profiles')
              .select('xp')
              .eq('id', userId)
              .maybeSingle();
          
          if (profileData != null && profileData['xp'] != null) {
             currentXp = profileData['xp']; // Pakai data server kalau ada
          }
        } catch (e) {
          debugPrint("Gagal ambil XP server, pake lokal dulu: $e");
        }
      }

      // 3. Hitung XP Baru
      int newTotalXp = currentXp + _xpGained;

      // 4. SIMPAN KE SERVER (Supabase) - Ini kunci biar gak ilang pas install ulang!
      if (userId != null) {
        await supabase.from('profiles').upsert({
          'id': userId,
          'xp': newTotalXp,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // 5. Simpan ke Lokal juga (biar sinkron)
      await prefs.setInt('user_xp', newTotalXp);

      // 6. Update tampilan Dialog
      if (mounted) {
        setState(() {
          _currentTotalXp = newTotalXp;
          _currentLevel = _currentTotalXp ~/ xpPerLevel;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error updating XP: $e");
      // Fallback: matikan loading biar user gak stuck, meski data mungkin gak ke-save sempurna
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper buat ambil gelar sesuai bahasa
  String _getChefTitle(int level, LanguageProvider lang) {
    if (level < 2) return lang.getText('chef_title_1'); 
    if (level < 5) return lang.getText('chef_title_2'); 
    if (level < 10) return lang.getText('chef_title_3'); 
    if (level < 20) return lang.getText('chef_title_4'); 
    return lang.getText('chef_title_5'); 
  }

  @override
  Widget build(BuildContext context) {
    // 1. PANGGIL PROVIDER BAHASA
    final lang = context.watch<LanguageProvider>();

    if (_isLoading) {
       // Tampilkan loading biar user tau lagi proses simpan
       return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    final title = _getChefTitle(_currentLevel, lang);
    
    int currentLevelBaseXp = _currentLevel * xpPerLevel;
    int xpInCurrentLevel = _currentTotalXp - currentLevelBaseXp;
    double progress = xpInCurrentLevel / xpPerLevel;
    // Clamp progress biar gak error kalau > 1.0
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gambar Hore
                ClipOval(
                  child: Container(
                    color: Colors.amber.withOpacity(0.2),
                    child: Image.asset(
                      ChefCeiAssets.berhasil, 
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Judul Selamat
                Text(
                  lang.getText('recipe_completed'), 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Info XP yang didapat
                Text(
                  lang.getText('xp_earned_msg').replaceAll('@xp', '$_xpGained'), 
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
                
                const SizedBox(height: 20),
                
                // Kotak Progress Level
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                             "${lang.getText('level_label')} $_currentLevel", 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)
                           ),
                           Text("$xpInCurrentLevel / $xpPerLevel XP", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[300], valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${lang.getText('title_label')} $title", 
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Tombol Tutup
                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: StadiumBorder(
                      side: BorderSide(color: Colors.amber.shade700, width: 2),
                    ),
                    elevation: 4,
                  ),
                  child: Text(lang.getText('continue_cooking'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}