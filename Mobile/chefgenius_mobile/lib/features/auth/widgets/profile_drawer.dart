import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/providers/language_provider.dart';

class ProfileDrawer extends StatelessWidget {
  final String? fullName;
  final String? username;
  final String email;
  final VoidCallback onLogout;

  const ProfileDrawer({
    super.key,
    required this.fullName,
    required this.username,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final displayName = fullName ?? username ?? "Chef";
    
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -30,
                  child: Icon(Icons.restaurant_menu, size: 180, color: Colors.white.withValues(alpha: 0.1)),
                ),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/Chef_Cei/chef_cei_tangankebawah.png',
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Menu Chef",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "Halo,",
                        style: TextStyle(color: Colors.orange.shade100, fontSize: 16),
                      ),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildDrawerItem(
                  icon: Icons.favorite_rounded,
                  color: Colors.redAccent,
                  title: lang.getText('fav_btn'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.favoriteRecipesRoute);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bookmark_rounded,
                  color: Colors.amber,
                  title: "Koleksi Inspirasi",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.savedPostsRoute);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  color: Colors.grey.shade700,
                  title: lang.getText('settings_title'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.settingsRoute);
                  },
                ),
                if (email == "inceiqbals6@gmail.com")
                  _buildDrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.deepPurple,
                    title: "Admin Dashboard",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.adminDashboardRoute);
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(),
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  color: Colors.red,
                  title: lang.getText('logout_btn'),
                  onTap: () {
                    Navigator.pop(context);
                    onLogout();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco, size: 14, color: Colors.green.shade300),
                const SizedBox(width: 4),
                Text(
                  "ChefGenius v1.0",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
