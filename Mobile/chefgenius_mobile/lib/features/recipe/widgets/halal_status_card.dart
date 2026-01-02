import 'package:flutter/material.dart';

/// Widget untuk menampilkan status halal resep dengan styling yang sesuai
/// - Halal: hijau dengan checkmark
/// - Non-Halal: merah dengan warning + daftar bahan terdeteksi
/// - Unknown: orange dengan tanda tanya
class HalalStatusCard extends StatelessWidget {
  final String halalStatus;
  final List<String> detectedNonHalal;

  const HalalStatusCard({
    super.key,
    required this.halalStatus,
    this.detectedNonHalal = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isNonHalal = halalStatus.toLowerCase().contains('non');
    final isUnknown = halalStatus.toLowerCase().contains('unknown');
    
    // Determine colors and icon based on status
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    
    if (isNonHalal) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      textColor = Colors.red.shade700;
      icon = Icons.warning_amber_rounded;
    } else if (isUnknown) {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      textColor = Colors.orange.shade700;
      icon = Icons.help_outline_rounded;
    } else {
      // Halal
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      textColor = Colors.green.shade700;
      icon = Icons.verified_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Halal',
            style: Theme.of(context)
                .textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Row
                Row(
                  children: [
                    Icon(icon, color: textColor, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        halalStatus,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Show detected ingredients if non-halal
                if (isNonHalal && detectedNonHalal.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Bahan non-halal terdeteksi:',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...detectedNonHalal.map((ingredient) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          
          const Divider(height: 24),
        ],
      ),
    );
  }
}
