import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SaveCollectionDialog extends StatefulWidget {
  final String userId;
  const SaveCollectionDialog({super.key, required this.userId});

  @override
  State<SaveCollectionDialog> createState() => _SaveCollectionDialogState();
}

class _SaveCollectionDialogState extends State<SaveCollectionDialog> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    try {
      final response = await supabase
          .from('collections')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _collections = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching collections: $e");
      // If table doesn't exist yet, just show empty list
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createCollection() async {
    final TextEditingController controller = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Buat Koleksi Baru",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: "Nama Koleksi",
                  hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isDarkMode ? Colors.grey[600]! : Colors.grey.shade300),
                        ),
                      ),
                      child: Text("Batal", style: TextStyle(color: textColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text("Buat"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final res = await supabase
            .from('collections')
            .insert({'user_id': widget.userId, 'name': name})
            .select()
            .single();
        
        if (mounted) {
          setState(() {
            _collections.insert(0, res);
          });
          // Automatically select the new collection
          Navigator.pop(context, res['id']);
        }
      } catch (e) {
        debugPrint("Error creating collection: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal membuat koleksi: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Simpan ke...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.bookmark_border),
                        title: const Text("Semua Postingan"),
                        onTap: () => Navigator.pop(context, 'all_posts'), // 'all_posts' means no specific collection
                      ),
                      ..._collections.map((collection) => ListTile(
                        leading: const Icon(Icons.folder_open),
                        title: Text(collection['name']),
                        onTap: () => Navigator.pop(context, collection['id']),
                      )),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: Colors.orange),
                        title: const Text("Buat Koleksi Baru", style: TextStyle(color: Colors.orange)),
                        onTap: _createCollection,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
