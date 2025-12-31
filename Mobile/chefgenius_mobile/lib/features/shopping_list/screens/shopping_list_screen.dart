import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/shopping_list_provider.dart';
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER
import '../../../app/widgets/offline_banner.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _itemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isOffline = context.read<ConnectivityProvider>().isOffline;
      context.read<ShoppingListProvider>().loadItems(isOffline);
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH LANGUAGE PROVIDER
    final lang = context.watch<LanguageProvider>();
    
    final provider = context.watch<ShoppingListProvider>();
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final groupedItems = provider.groupedItems;
    
    // Cek Mode Gelap
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final allItems = groupedItems.values.expand((element) => element).toList();
    final isAllChecked = allItems.isNotEmpty && allItems.every((item) => item.isChecked);
    final hasCheckedItems = allItems.any((item) => item.isChecked);

    // Warna Dinamis
    final backgroundColor = isDarkMode ? Colors.black : Colors.grey[50];
    final surfaceColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final borderColor = (isDarkMode ? Colors.grey[800] : Colors.grey[300]) ?? Colors.grey;
    final inputFillColor = isDarkMode ? Colors.grey[800] : Colors.grey[50];

    return Scaffold(
      backgroundColor: backgroundColor, 
      appBar: CustomAppBar(title: lang.getText('shopping_title')), // Teks Dinamis
      body: Column(
        children: [
          const OfflineBanner(),

          // --- INFO BANNER (Disclaimer) ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDarkMode ? Colors.orange.withOpacity(0.3) : Colors.orange.shade100),
            ),
            child: Row(
              children: [
                 Icon(Icons.info_outline_rounded, size: 20, color: isDarkMode ? Colors.orangeAccent : Colors.orange),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     lang.getText('shopping_disclaimer'),
                     style: TextStyle(
                       fontSize: 13,
                       fontWeight: FontWeight.w500,
                       color: isDarkMode ? Colors.orange[200] : Colors.orange[900],
                     ),
                   ),
                 ),
              ],
            ),
          ),
          
          // --- BAGIAN INPUT & KONTROL ---
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 1. Input Manual
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: TextField(
                          controller: _itemController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: lang.getText('shopping_hint'), 
                            hintStyle: TextStyle(color: subTextColor),
                            prefixIcon: const Icon(Icons.playlist_add_rounded, color: Colors.orange), 
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.orange, width: 1.5),
                            ),
                            filled: true,
                            fillColor: inputFillColor,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                          onSubmitted: (_) => _addItem(provider, isOffline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        ]
                      ),
                      child: IconButton.filled(
                        onPressed: () => _addItem(provider, isOffline),
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.white), 
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: "Catat item",
                      ),
                    )
                  ],
                ),

                // 2. Tombol "Pilih Semua" & "Hapus Terpilih"
                if (allItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Select All
                      InkWell(
                        onTap: () {
                          provider.toggleAll(!isAllChecked, isOffline);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isAllChecked ? Colors.orange : Colors.transparent,
                                  border: Border.all(
                                    color: isAllChecked ? Colors.orange : (isDarkMode ? Colors.grey[600]! : Colors.grey.shade400),
                                    width: 2
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.check, 
                                  size: 14, 
                                  color: isAllChecked ? Colors.white : Colors.transparent
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAllChecked 
                                    ? lang.getText('unselect_all') 
                                    : lang.getText('select_all'), 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tombol Hapus Massal
                      if (hasCheckedItems)
                        TextButton.icon(
                          onPressed: () => _confirmDeleteSelected(context, provider, allItems, isOffline),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          label: Text(lang.getText('delete_selected'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // --- LIST BARANG ---
          Expanded(
            child: provider.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : groupedItems.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.8,
                          child: Image.asset(
                            'assets/images/Chef_Cei/chefceimegangkeranjang.png',
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          lang.getText('shopping_empty_title'), 
                          style: TextStyle(color: subTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Yuk catat bahan yang habis biar nggak lupa!", 
                          style: TextStyle(color: subTextColor, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: groupedItems.keys.length,
                    itemBuilder: (context, index) {
                      String title = groupedItems.keys.elementAt(index);
                      var items = groupedItems[title]!;
                      
                      bool isManualGroup = title == 'Tambahan Lain';

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                          border: Border.all(color: borderColor.withOpacity(0.5)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // HEADER GRUP
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isManualGroup 
                                    ? (isDarkMode ? Colors.grey[850] : Colors.grey[100]) 
                                    : (isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50),
                                border: Border(bottom: BorderSide(color: borderColor.withOpacity(0.5)))
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isManualGroup ? Colors.grey.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isManualGroup ? Icons.list_alt_rounded : Icons.restaurant_menu_rounded, 
                                      size: 18, 
                                      color: isManualGroup ? subTextColor : Colors.orange[800]
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: isManualGroup 
                                            ? textColor 
                                            : (isDarkMode ? Colors.orange[300] : Colors.orange[900]),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                                    tooltip: "Hapus grup ini", 
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _confirmDeleteGroup(context, title, provider, isOffline);
                                    },
                                  )
                                ],
                              ),
                            ),
                            
                            // LIST ITEM
                            ...items.map((item) {
                              return Dismissible(
                                key: Key(item.key.toString()), 
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red.shade50,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("Hapus", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                                    ],
                                  ),
                                ),
                                onDismissed: (direction) {
                                  provider.deleteItem(item, isOffline);
                                },
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      value: item.isChecked, 
                                      onChanged: (val) => provider.toggleCheck(item, val ?? false, isOffline),
                                      title: Text(
                                        item.itemName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: item.isChecked ? FontWeight.normal : FontWeight.w500,
                                          decoration: item.isChecked ? TextDecoration.lineThrough : null,
                                          decorationColor: Colors.orange,
                                          decorationThickness: 2,
                                          color: item.isChecked ? subTextColor : textColor,
                                        ),
                                      ),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      activeColor: Colors.orange,
                                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      dense: true,
                                    ),
                                    if (item != items.last) 
                                      Divider(height: 1, thickness: 0.5, color: borderColor.withOpacity(0.5), indent: 56),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- HELPER METHODS ---
  void _addItem(ShoppingListProvider provider, bool isOffline) {
    if (_itemController.text.trim().isNotEmpty) {
      provider.addItem(_itemController.text.trim(), isOffline);
      _itemController.clear();
    }
  }

  void _confirmDeleteGroup(BuildContext context, String title, ShoppingListProvider provider, bool isOffline) {
    // Ambil lang provider di sini
    final lang = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('delete_group_title').replaceAll('@title', title)), // "Hapus [Judul]?"
        content: Text(lang.getText('delete_group_desc')), // "Semua item..."
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.getText('cancel'))), // "Batal"
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteGroup(title, isOffline);
            },
            child: Text(lang.getText('delete_btn'), style: const TextStyle(color: Colors.red)), // "Hapus"
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context, ShoppingListProvider provider, List<dynamic> allItems, bool isOffline) {
    // Ambil lang provider di sini
    final lang = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('delete_selected_title')), // "Hapus item terpilih?"
        content: Text(lang.getText('delete_selected_desc')), // "Item yang sudah..."
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text(lang.getText('cancel')) // "Batal"
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final checkedItems = allItems.where((i) => i.isChecked).toList();
              for (var item in checkedItems) {
                provider.deleteItem(item, isOffline);
              }
            }, 
            child: Text(lang.getText('delete_btn'), style: const TextStyle(color: Colors.red)) // "Hapus"
          ),
        ],
      ),
    );
  }
}