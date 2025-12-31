import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SanctionedUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color textColor;
  final Color cardColor;
  final VoidCallback onRevoke;

  const SanctionedUserCard({
    super.key,
    required this.user,
    required this.textColor,
    required this.cardColor,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final level = user['warning_level'] ?? 0;
    final endTimeStr = user['sanction_end_time'];
    String statusText = "";
    Color statusColor = Colors.grey;

    if (level == 1) {
      statusText = "Level 1 (Dibatasi)";
      statusColor = Colors.orange;
    } else if (level == 2) {
      statusText = "Level 2 (Read Only)";
      statusColor = Colors.deepOrange;
    } else if (level >= 3) {
      statusText = "Level 3 (BANNED)";
      statusColor = Colors.red;
    }

    String durationText = "Permanen";
    if (endTimeStr != null) {
      final endTime = DateTime.parse(endTimeStr).toLocal();
      durationText = "Sampai: ${DateFormat('d MMM yyyy HH:mm').format(endTime)}";
      
      // Cek apakah sudah expired tapi belum diupdate
      if (DateTime.now().isAfter(endTime)) {
        durationText += " (Expired)";
        statusColor = Colors.grey;
      }
    }

    return Card(
      color: cardColor,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                    backgroundImage: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                      ? (user['avatar_url'].toString().startsWith('asset:')
                        ? AssetImage(user['avatar_url'].toString().substring(6).trim()) as ImageProvider<Object>
                        : user['avatar_url'].toString().startsWith('assets/')
                          ? AssetImage(user['avatar_url'].toString()) as ImageProvider<Object>
                          : (user['avatar_url'].toString().startsWith('http://') || user['avatar_url'].toString().startsWith('https://'))
                            ? CachedNetworkImageProvider(user['avatar_url'].toString()) as ImageProvider<Object>
                            : null)
                      : null,
                  child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? user['username'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      Text(
                        "@${user['username'] ?? '-'}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  durationText,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Cabut Sanksi?"),
                        content: const Text("Apakah Anda yakin ingin mencabut sanksi untuk user ini? User akan kembali normal."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onRevoke();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Ya, Cabut Sanksi"),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text("Batalkan Sanksi"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
