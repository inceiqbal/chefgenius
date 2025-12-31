import 'package:flutter/material.dart';

class RecipeInfoSection extends StatelessWidget {
  final String title;
  final String data;
  final IconData? icon;
  final Color? iconColor;
  final bool withDivider;

  const RecipeInfoSection({
    super.key,
    required this.title,
    required this.data,
    this.icon,
    this.iconColor,
    this.withDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (icon != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0), 
                  child: Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data,
                    style:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            )
          else
            Text(
              data,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              textAlign: TextAlign.justify,
            ),
          
          if (withDivider) const Divider(height: 24),
        ],
      ),
    );
  }
}
