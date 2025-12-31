import 'package:flutter/material.dart';
// import '../../../app/config/chef_cei_assets.dart';

class LevelInfoDialog extends StatelessWidget {
  final int currentLevel;
  final String currentTitle;

  const LevelInfoDialog({
    super.key,
    required this.currentLevel,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 60),
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0), // Soft Orange
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.orange.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "LEVEL & AWARDS",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.deepOrange,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Level Kamu: $currentLevel ($currentTitle)",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: [
                      _buildLevelItem(0, "Newbie", Icons.kitchen, "Akses Resep Dasar"),
                      _buildLevelItem(2, "Home Cook", Icons.restaurant, "Fitur Pilih Negara"),
                      _buildLevelItem(5, "Chef", Icons.restaurant_menu, "Fitur Filter Diet"),
                      _buildLevelItem(10, "Sous Chef", Icons.local_dining, "Fitur Jumlah Resep > 1"),
                      _buildLevelItem(20, "Master Chef", Icons.workspace_premium, "Badge Spesial & Prioritas"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Tutup"),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Image.asset(
              'assets/images/Chef_Cei/chefceiintro.png',
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelItem(int level, String title, IconData icon, String award) {
    final bool isUnlocked = currentLevel >= level;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? Colors.orange.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUnlocked ? Colors.orange.shade50 : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              size: 20, 
              color: isUnlocked ? Colors.orange : Colors.grey
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Level $level - $title",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Award: $award",
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? Colors.orange.shade800 : Colors.grey.shade500,
                    fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
