import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/notification_provider.dart';
import '../../../app/widgets/animated_notification_badge.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../providers/community_provider.dart';

class CommunityAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearchingMode;
  final TextEditingController searchController;
  final VoidCallback onSearchClose;
  final VoidCallback onSearchTap;
  final VoidCallback onUploadPressed;
  final DateTime? sanctionEndTime;
  final String remainingTime;

  const CommunityAppBar({
    super.key,
    required this.isSearchingMode,
    required this.searchController,
    required this.onSearchClose,
    required this.onSearchTap,
    required this.onUploadPressed,
    this.sanctionEndTime,
    required this.remainingTime,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8F0),
      leading: isSearchingMode 
        ? IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDarkMode ? Colors.white : Colors.black87),
            onPressed: onSearchClose,
          )
        : null,
      title: isSearchingMode
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Cari resep, judul, atau caption...",
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500, fontSize: 14),
                border: InputBorder.none,
                icon: Icon(Icons.search_rounded, color: Colors.orange, size: 20),
              ),
              onSubmitted: (value) {
                context.read<CommunityProvider>().setSearchQuery(value.trim());
              },
            ),
          )
        : Row(
            children: [
              // Logo/Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.getText('comm_title'), 
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (sanctionEndTime != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "⚠️ Sanksi: $remainingTime",
                        style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
      centerTitle: false,
      actions: [
        if (!isOffline) ...[
          if (isSearchingMode)
            IconButton(
              icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white : Colors.black87),
              onPressed: () {
                searchController.clear();
                onSearchClose();
              },
            )
          else
            IconButton(
              icon: Icon(Icons.search_rounded, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
              onPressed: onSearchTap,
            ),
          
          if (!isSearchingMode) ...[
            Consumer<NotificationProvider>(
              builder: (context, notifProvider, child) {
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                        );
                      },
                    ),
                    if (notifProvider.unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: AnimatedNotificationBadge(count: notifProvider.unreadCount),
                      ),
                  ],
                );
              },
            ),
            // Modern Add Button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onUploadPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE67E22).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
