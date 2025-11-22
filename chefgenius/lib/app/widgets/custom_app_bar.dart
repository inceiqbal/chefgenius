import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? elevation;
  final Widget? leading;
  final bool centerTitle;
  
  // TAMBAHAN BARU: Buat ngatur jarak kiri judul
  final double? titleSpacing; 

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.leading,
    this.centerTitle = false, // Default Kiri
    this.titleSpacing,        // Default Null (ikut standar Flutter)
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      actions: actions,
      backgroundColor: backgroundColor, 
      elevation: elevation,
      leading: leading,
      titleSpacing: titleSpacing, // Pasang di sini
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}