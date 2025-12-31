import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/connectivity_provider.dart';

class RepoFloatingButton extends StatelessWidget {
  final GlobalKey? showcaseKey;
  final VoidCallback onReturn;

  const RepoFloatingButton({
    super.key,
    this.showcaseKey,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    // Kita gak butuh tinggi layar buat center horizontal, cukup Positioned left-right 0
    
    return Positioned(
      // --- POSISI EMANSIPASI (DI TENGAH) ---
      // Kita taruh agak bawah (bottom 130) biar gak menuhin tengah layar,
      // TAPI cukup tinggi biar gak ketumpuk sama tombol AI di paling bawah.
      bottom: 130, 
      left: 0, 
      right: 0, 
      child: Center( // Center ini kuncinya biar dia di tengah horizontal
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              // --- CEK KONEKSI ---
              final isOffline = context.read<ConnectivityProvider>().isOffline;

              if (isOffline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ups, lagi offline nih Bestie! 📶\nBuku resepnya gak bisa dibuka dulu ya. Coba cari sinyal yuk!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                Navigator.pushNamed(context, AppRoutes.recipeSearchRoute)
                    .then((_) => onReturn());
              }
            },
            child: Container(
              // BENTUK: KAPSUL PENUH (Stadium)
              // Lebih enak dilihat daripada kotak/setengah lingkaran
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
              ),
              // KONTEN: ICON + TEKS JELAS
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Cari Resep Lainnya", // Teks lebih persuasif dikit
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}