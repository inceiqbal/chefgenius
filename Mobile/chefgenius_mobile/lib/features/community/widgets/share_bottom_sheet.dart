import 'package:flutter/material.dart';
import 'package:chefgenius/app/config.dart';

class ShareBottomSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final int index;
  final Function(Map<String, dynamic>, int) onShareSuccess;

  const ShareBottomSheet({
    super.key,
    required this.post,
    required this.index,
    required this.onShareSuccess,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  @override
  Widget build(BuildContext context) {
    // Pastikan ini domain baru biar tampilan di UI bener
    final String postLink = '$SHARE_BASE_URL${widget.post['id']}';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Bagikan Postingan",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image, color: Colors.orange),
            ),
            title: const Text("Bagikan (Gambar + Teks)"),
            subtitle: const Text("Sertakan media dan caption (cocok untuk Instagram)"),
            onTap: () => Navigator.pop(context, 'image_text'),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.text_snippet, color: Colors.orange),
            ),
            title: const Text("Bagikan (Teks saja)"),
            subtitle: const Text("Hanya caption + tautan"),
            onTap: () => Navigator.pop(context, 'text_only'),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.copy_all, color: Colors.orange),
            ),
            title: const Text("Salin Caption"),
            subtitle: Text(widget.post['caption'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, 'copy_caption'),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link, color: Colors.orange),
            ),
            title: const Text("Salin Tautan"),
            subtitle: Text(postLink, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, 'copy_link'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}