import 'package:flutter/material.dart';
import '../../../app/config/chef_cei_assets.dart';

class PantryEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const PantryEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            ChefCeiAssets.kosong,
            width: 150, 
            fit: BoxFit.contain
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
