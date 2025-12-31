import 'package:flutter/material.dart';
import 'admin_common_widgets.dart';

class AppealCard extends StatelessWidget {
  final Map<String, dynamic> appeal;
  final Color textColor;
  final Color cardColor;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const AppealCard({
    super.key,
    required this.appeal,
    required this.textColor,
    required this.cardColor,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = appeal['profiles'];
    final status = appeal['status'] ?? 'pending';
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AdminUserAvatar(url: user?['avatar_url'], name: user?['username'] ?? 'User', radius: 20),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['username'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                        ),
                        Text(
                          "Level Sanksi: ${user?['warning_level'] ?? 0}",
                          style: TextStyle(fontSize: 12, color: Colors.red[400]),
                        ),
                      ],
                    ),
                  ],
                ),
                AdminStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                appeal['reason'] ?? "-",
                style: TextStyle(fontStyle: FontStyle.italic, color: textColor),
              ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Tolak"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Terima"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
