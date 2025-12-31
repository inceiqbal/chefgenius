import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const AdminEmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}

class AdminStatusBadge extends StatelessWidget {
  final String status;

  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    
    switch (status) {
      case 'resolved':
      case 'approved':
        color = Colors.green;
        text = status == 'approved' ? 'DITERIMA' : 'SELESAI';
        break;
      case 'rejected':
      case 'ignored':
        color = Colors.grey;
        text = status == 'rejected' ? 'DITOLAK' : 'DIABAIKAN';
        break;
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class AdminUserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const AdminUserAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    final String? safeUrl = url;
    if (safeUrl != null && safeUrl.isNotEmpty) {
      if (safeUrl.startsWith('asset:')) {
        final assetPath = safeUrl.length > 6 ? safeUrl.substring(6).trim() : null;
        if (assetPath != null && assetPath.isNotEmpty) {
          imageProvider = AssetImage(assetPath);
        }
      } else if (safeUrl.startsWith('assets/')) {
        imageProvider = AssetImage(safeUrl);
      } else if (safeUrl.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(safeUrl);
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: radius, color: Colors.grey[600]))
          : null,
    );
  }
}
