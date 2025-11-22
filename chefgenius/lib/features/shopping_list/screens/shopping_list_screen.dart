import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/shopping_list_provider.dart';
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
    // Load data pas pertama kali buka screen
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
    final provider = context.watch<ShoppingListProvider>();
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final groupedItems = provider.groupedItems;

    // --- LOGIKA UI UNTUK SELECT ALL ---
    // Kita ratain semua item jadi satu list panjang buat ngecek statusnya
    final allItems = groupedItems.values.expand((element) => element).toList();
    
    // Cek: Apakah semua item kondisinya 'checked'?
    final isAllChecked = allItems.isNotEmpty && allItems.every((item) => item.isChecked);
    
    // Cek: Apakah ada minimal satu item yang dicentang (buat nampilin tombol hapus massal)
    final hasCheckedItems = allItems.any((item) => item.isChecked);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Kasih background dikit biar gak pucat
      appBar: const CustomAppBar(title: 'Keranjang Belanja'),
      body: Column(
        children: [
          const OfflineBanner(),
          
          // --- BAGIAN INPUT & KONTROL ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 1. Input Manual
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemController,
                        decoration: InputDecoration(
                          hintText: 'Tambah belanjaan manual...',
                          prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.orange),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.orange),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        ),
                        onSubmitted: (_) => _addItem(provider, isOffline),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _addItem(provider, isOffline),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  ],
                ),

                // 2. Tombol "Pilih Semua" & "Hapus Terpilih"
                // Cuma muncul kalau list gak kosong
                if (allItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Select All / Unselect All
                      InkWell(
                        onTap: () {
                          // Panggil fungsi sakti di Provider
                          // Kalau isAllChecked true, kita minta false (uncheck semua), dan sebaliknya.
                          provider.toggleAll(!isAllChecked, isOffline);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            children: [
                              // Custom Checkbox UI
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isAllChecked ? Colors.orange : Colors.transparent,
                                  border: Border.all(
                                    color: isAllChecked ? Colors.orange : Colors.grey.shade400,
                                    width: 2
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.check, 
                                  size: 14, 
                                  color: isAllChecked ? Colors.white : Colors.transparent
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAllChecked ? "Batal Pilih Semua" : "Pilih Semua",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tombol Hapus Massal (Muncul cuma kalau ada yang dicentang)
                      if (hasCheckedItems)
                        TextButton.icon(
                          onPressed: () => _confirmDeleteSelected(context, provider, allItems, isOffline),
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: const Text("Hapus Terpilih", style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        // --- VISUAL CHEF CEI MEGANG KERANJANG ---
                        Image.asset(
                          'assets/images/Chef_Cei/chefceimegangkeranjang.png', // Ganti Icon jadi Gambar
                          height: 200, // Ukuran gambar disesuaikan
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Keranjang kosong melompong.", 
                          style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Yuk belanja bareng Cei!", 
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                      
                      // Cek apakah ini grup "Tambahan Lain" buat bedain warna
                      bool isManualGroup = title == 'Tambahan Lain';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              // HEADER GRUP
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isManualGroup ? Colors.grey[100] : Colors.orange[50],
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade100))
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isManualGroup ? Icons.list_alt : Icons.restaurant_menu, 
                                      size: 18, 
                                      color: isManualGroup ? Colors.grey[600] : Colors.orange[800]
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 15,
                                          color: isManualGroup ? Colors.grey[800] : Colors.orange[900],
                                        ),
                                      ),
                                    ),
                                    
                                    // Tombol Hapus Satu Grup
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.grey[400], size: 18),
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
                                    color: Colors.red[50],
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.red),
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
                                            decoration: item.isChecked ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.orange,
                                            decorationThickness: 2,
                                            color: item.isChecked ? Colors.grey[400] : Colors.black87,
                                          ),
                                        ),
                                        controlAffinity: ListTileControlAffinity.leading,
                                        activeColor: Colors.orange,
                                        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        dense: true,
                                      ),
                                      if (item != items.last) 
                                        Divider(height: 1, thickness: 0.5, color: Colors.grey[100], indent: 50),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Hapus $title?"),
        content: const Text("Semua item dalam grup ini bakal dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteGroup(title, isOffline);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context, ShoppingListProvider provider, List<dynamic> allItems, bool isOffline) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus item terpilih?"),
        content: const Text("Item yang sudah dicentang akan dihapus permanen."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Batal")
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Ambil yang dicentang, terus hapus satu-satu
              // (Atau kalau mau canggih nanti bikin method deleteBatch di provider)
              final checkedItems = allItems.where((i) => i.isChecked).toList();
              for (var item in checkedItems) {
                provider.deleteItem(item, isOffline);
              }
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}