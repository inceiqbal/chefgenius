import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'admin_common_widgets.dart';

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Color textColor;
  final Color cardColor;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const ReportCard({
    super.key,
    required this.report,
    required this.textColor,
    required this.cardColor,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final status = report['status'] ?? 'pending';
    final isResolved = status == 'resolved';
    final isIgnored = status == 'ignored';
    
    final reporter = report['profiles'];
    final reported = report['reported_profile'];
    final post = report['posts'];
    final comment = report['comments'];
    final isCommentReport = comment != null || (report['reason'] as String).contains("[REPORT COMMENT]");

    void _goToProfile(String? userId) {
      if (userId == null || userId.isEmpty) return;
      Navigator.of(context).pushNamed('/profile', arguments: userId);
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AdminStatusBadge(status: status),
                const Spacer(),
                Text(
                  timeago.format(DateTime.parse(report['created_at']).toLocal(), locale: 'id'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _goToProfile(reporter?['id']?.toString()),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AdminUserAvatar(url: reporter?['avatar_url'], name: reporter?['username'] ?? 'Anonim', radius: 14),
                          const SizedBox(width: 4),
                          Text(
                            reporter?['username'] ?? 'Anonim',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("melaporkan", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _goToProfile(reported?['id']?.toString()),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          AdminUserAvatar(url: reported?['avatar_url'], name: reported?['username'] ?? 'Unknown', radius: 14),
                          const SizedBox(width: 4),
                          Text(
                            reported?['username'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Alasan: ${report['reason']}",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                ),
                const SizedBox(height: 16),
                
                // Reported Content Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: isCommentReport 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.comment_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text("Komentar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              comment?['content'] ?? "Konten telah dihapus",
                              style: TextStyle(fontStyle: FontStyle.italic, color: textColor),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            if (post != null && post['image_url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: post['image_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.image_rounded, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text("Postingan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    post?['caption'] ?? "Konten telah dihapus",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Actions
          if (!isResolved && !isIgnored)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Abaikan"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Tindak"),
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
