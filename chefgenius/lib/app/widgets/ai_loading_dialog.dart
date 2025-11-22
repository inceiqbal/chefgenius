import 'package:flutter/material.dart';
import '../config/chef_cei_assets.dart'; // Import aset tadi

class AiLoadingDialog extends StatelessWidget {
  final String text;
  final String? imagePath; // Opsional: Bisa ganti gambar sesuai konteks

  const AiLoadingDialog({
    super.key, 
    required this.text,
    this.imagePath, // Default-nya null, nanti kita set default di build
  });

  @override
  Widget build(BuildContext context) {
    // Default pake pose "Mikir" kalau gak diset
    final String currentImage = imagePath ?? ChefCeiAssets.mikir;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gambar Chef Cei (Animasi dikit biar hidup)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                currentImage,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            
            // Loading Indicator Bar
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            
            // Teks Loading
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}