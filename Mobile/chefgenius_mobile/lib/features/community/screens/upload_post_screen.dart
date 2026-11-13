import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';

class UploadPostScreen extends StatefulWidget {
  final int? initialRecipeId;
  final String? initialRecipeTitle;

  const UploadPostScreen({
    super.key, 
    this.initialRecipeId, 
    this.initialRecipeTitle
  });

  @override
  State<UploadPostScreen> createState() => _UploadPostScreenState();
}

class _UploadPostScreenState extends State<UploadPostScreen> {
  // Media State
  final List<Map<String, dynamic>> _mediaItems = []; // {file: File, type: 'image'|'video', thumbnail: File?}
  
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController(); 
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _selectedCategory; 

  // Variabel untuk fitur Recook
  bool _isRecook = false;
  int? _selectedRecipeId;
  String? _selectedRecipeTitle;
  List<Map<String, dynamic>> _recipeSearchResults = [];
  bool _isSearchingRecipe = false;
  final TextEditingController _recipeSearchController = TextEditingController();

  final List<String> _categories = ['Makanan', 'Minuman', 'Set Menu']; 
  
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipeId != null) {
      _isRecook = true;
      _selectedRecipeId = widget.initialRecipeId;
      _selectedRecipeTitle = widget.initialRecipeTitle;
      _selectedCategory = 'Makanan'; 
    }
  }

  Future<void> _searchRecipes(String query) async {
    if (query.isEmpty) {
      setState(() => _recipeSearchResults = []);
      return;
    }

    setState(() => _isSearchingRecipe = true);
    try {
      final response = await supabase
          .from('recipes')
          .select('id, title')
          .ilike('title', '%$query%')
          .limit(5);
      
      if (mounted) {
        setState(() {
          _recipeSearchResults = List<Map<String, dynamic>>.from(response);
          _isSearchingRecipe = false;
        });
      }
    } catch (e) {
      debugPrint("Error search recipe: $e");
      if (mounted) setState(() => _isSearchingRecipe = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_mediaItems.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maksimal 10 slide ya Bestie! Biar gak kebanyakan scroll.")),
      );
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _picker.pickMultiImage(
          imageQuality: 70, // Sedikit dinaikkan biar bagus
          maxWidth: 1080,
        );
        
        if (pickedFiles.isNotEmpty) {
          setState(() {
            for (var file in pickedFiles) {
              if (_mediaItems.length < 10) {
                final f = File(file.path);
                // Cek Size (Max 10MB per foto)
                if (f.lengthSync() > 10 * 1024 * 1024) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Waduh, fotonya kegedean! Maksimal 10MB ya biar server gak pusing. 🤯")),
                   );
                   continue;
                }

                _mediaItems.add({
                  'file': f,
                  'type': 'image',
                });
              }
            }
          });
        }
      } else {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1080,
        );
        if (pickedFile != null) {
          final f = File(pickedFile.path);
          if (f.lengthSync() > 10 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Waduh, fotonya kegedean! Maksimal 10MB ya biar server gak pusing. 🤯")),
                );
              }
              return;
          }

          setState(() {
            _mediaItems.add({
              'file': f,
              'type': 'image',
            });
          });
        }
      }
    } catch (e) {
      debugPrint("Error pick image: $e");
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_mediaItems.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maksimal 10 slide ya Bestie!")),
      );
      return;
    }

    try {
      // Max Duration 60 detik (1 menit)
      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60), 
      );
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        
        // Cek Size (Max 50MB per video)
        final sizeInMb = file.lengthSync() / (1024 * 1024);
        if (sizeInMb > 50) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Waduh, videonya berat banget! Maksimal 50MB ya, coba kompres dulu atau potong lagi. 🎥")),
             );
           }
           return;
        }

        // Generate Thumbnail
        File? thumbnailFile;
        try {
          final uint8list = await VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 300,
            quality: 50,
          );
          if (uint8list != null) {
            final tempDir = await getTemporaryDirectory();
            thumbnailFile = await File('${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
            await thumbnailFile.writeAsBytes(uint8list);
          }
        } catch (e) {
          debugPrint("Gagal generate thumbnail: $e");
        }

        setState(() {
          _mediaItems.add({
            'file': file,
            'type': 'video',
            'thumbnail': thumbnailFile,
          });
        });
      }
    } catch (e) {
      debugPrint("Error pick video: $e");
    }
  }

  void _previewVideo(File videoFile) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPreviewDialog(videoFile: videoFile),
    );
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  Future<void> _uploadPost() async {
    final isOffline = context.read<ConnectivityProvider>().isOffline;

    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lagi offline nih, postingnya nanti aja ya pas ada sinyal! 📡"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Media-nya mana nih? Jangan lupa upload foto atau video masakanmu ya! 📸")),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kategorinya belum dipilih nih! Masakan, Minuman, atau apa? 🤔"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      
      // 1. Upload Media & Collect URLs
      List<Map<String, dynamic>> uploadedMedia = [];
      String? firstImageUrl; // Untuk cover postingan (backward compatibility)
      String? firstVideoUrl;
      String? firstThumbnailUrl;

      for (int i = 0; i < _mediaItems.length; i++) {
        final item = _mediaItems[i];
        final file = item['file'] as File;
        final type = item['type'] as String;
        final fileExt = file.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${i}_$userId.$fileExt';
        
        String url = '';
        String? thumbUrl;

        if (type == 'image') {
          final filePath = 'posts/$fileName';
          await supabase.storage.from('community_uploads').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
          url = supabase.storage.from('community_uploads').getPublicUrl(filePath);
          
          if (i == 0) firstImageUrl = url;

        } else {
          final filePath = 'posts/videos/$fileName';
          await supabase.storage.from('community_uploads').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
          url = supabase.storage.from('community_uploads').getPublicUrl(filePath);
          
          if (i == 0) firstVideoUrl = url;

          // Upload Thumbnail
          if (item['thumbnail'] != null) {
            final thumbFile = item['thumbnail'] as File;
            final thumbName = 'thumb_$fileName.jpg';
            final thumbPath = 'posts/thumbnails/$thumbName';
            
            await supabase.storage.from('community_uploads').upload(
              thumbPath,
              thumbFile,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
            thumbUrl = supabase.storage.from('community_uploads').getPublicUrl(thumbPath);
            
            if (i == 0) firstThumbnailUrl = thumbUrl;
          }
        }

        uploadedMedia.add({
          'url': url,
          'type': type,
          'thumbnail_url': thumbUrl,
          'media_order': i
        });
      }

      // 2. Simpan ke Database Table 'posts'
      // Gunakan media pertama sebagai cover utama di tabel posts
      final postRes = await supabase.from('posts').insert({
        'user_id': userId,
        'image_url': firstImageUrl ?? firstThumbnailUrl ?? firstVideoUrl, // Prioritas: Image > Thumb Video > Video URL
        'caption': _captionController.text.trim(),
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'recipe_id': _isRecook ? _selectedRecipeId : null,
        'recipe_title': _isRecook ? _selectedRecipeTitle : null,
      }).select().single();

      final postId = postRes['id'];

      // 3. Simpan ke Table 'post_media'
      final List<Map<String, dynamic>> mediaInserts = uploadedMedia.map((m) => {
        'post_id': postId,
        'url': m['url'],
        'type': m['type'],
        'thumbnail_url': m['thumbnail_url'],
        'media_order': m['media_order']
      }).toList();

      await supabase.from('post_media').insert(mediaInserts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yey! Postinganmu udah tayang! 🎉"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yah, gagal posting. Coba lagi yuk! 🥺 $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8F0),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              lang.getText('upload_title'),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isUploading
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)))
                : GestureDetector(
                    onTap: _uploadPost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF121212)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFAFAFA)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview Area
              if (_mediaItems.isEmpty)
                _buildEmptyMediaPicker(isDarkMode, lang)
              else
                _buildMediaCarousel(isDarkMode),

              const SizedBox(height: 24),
              
              // Recook Toggle
              _buildRecookSection(isDarkMode),

              const SizedBox(height: 20),

              // Title Input
              _buildSectionLabel('Judul Hidangan', Icons.title_rounded, isDarkMode),
              const SizedBox(height: 8),
              _buildModernTextField(
                controller: _titleController,
                hint: 'Misal: Nasi Goreng Spesial',
                enabled: !_isRecook,
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Caption Input
              _buildSectionLabel('Caption', Icons.chat_bubble_outline_rounded, isDarkMode),
              const SizedBox(height: 8),
              _buildModernTextField(
                controller: _captionController,
                hint: lang.getText('upload_caption_hint'),
                maxLines: 3,
                isDarkMode: isDarkMode,
              ),

              const SizedBox(height: 20),

              // Category Dropdown
              _buildSectionLabel('Kategori', Icons.category_rounded, isDarkMode),
              const SizedBox(height: 8),
              _buildCategoryDropdown(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMediaPicker(bool isDarkMode, LanguageProvider lang) {
    return GestureDetector(
      onTap: () => _showMediaPicker(context),
      child: Container(
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFF2A2520).withOpacity(0.5), const Color(0xFF1E1A18).withOpacity(0.3)]
                : [Colors.orange.shade50.withOpacity(0.5), Colors.orange.shade100.withOpacity(0.3)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: const Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(lang.getText('upload_tap_hint'), style: TextStyle(color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Maksimal 10 Slide (Foto/Video)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(bool isDarkMode) {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: _mediaItems.length,
            itemBuilder: (context, index) {
              final item = _mediaItems[index];
              final file = item['file'] as File;
              final type = item['type'] as String;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: type == 'image'
                          ? Image.file(file, fit: BoxFit.cover)
                          : GestureDetector(
                              onTap: () => _previewVideo(file),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (item['thumbnail'] != null)
                                    Image.file(item['thumbnail'], fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                  else
                                    Container(color: Colors.black),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                    child: const Icon(Icons.play_arrow_rounded, size: 40, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeMedia(index),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                        child: Text('${index + 1}/${_mediaItems.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (type == 'video')
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE74C3C), Color(0xFFC0392B)]), borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.videocam_rounded, color: Colors.white, size: 14), SizedBox(width: 4), Text('Video', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_mediaItems.length < 10)
          GestureDetector(
            onTap: () => _showMediaPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 18, color: Colors.orange.shade600), const SizedBox(width: 6), Text('Tambah Slide', style: TextStyle(color: Colors.orange.shade600, fontWeight: FontWeight.w600))]),
            ),
          ),
      ],
    );
  }

  Widget _buildRecookSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.restaurant_menu_rounded, color: Colors.blue.shade600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hasil masak dari resep ChefGenius?', style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87)),
                  Text('Tandai untuk menautkan ke resep asli', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: _isRecook,
                  onChanged: (val) {
                    setState(() {
                      _isRecook = val;
                      if (!_isRecook) {
                        _selectedRecipeId = null;
                        _selectedRecipeTitle = null;
                        _recipeSearchController.clear();
                        _titleController.clear();
                      }
                    });
                  },
                  activeColor: Colors.orange,
                ),
              ),
            ],
          ),
          if (_isRecook) ...[
            const SizedBox(height: 16),
            if (_selectedRecipeTitle != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.5)]), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_selectedRecipeTitle!, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange))),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20), onPressed: () => setState(() { _selectedRecipeId = null; _selectedRecipeTitle = null; _titleController.clear(); })),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildModernTextField(controller: _recipeSearchController, hint: 'Cari nama resep...', isDarkMode: isDarkMode, prefixIcon: Icons.search_rounded, suffixWidget: _isSearchingRecipe ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null, onChanged: (val) { if (val.length > 2) _searchRecipes(val); }),
                  if (_recipeSearchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: ListView.separated(
                        shrinkWrap: true,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                        itemCount: _recipeSearchResults.length,
                        itemBuilder: (context, index) {
                          final recipe = _recipeSearchResults[index];
                          return ListTile(
                            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.restaurant_rounded, color: Colors.orange, size: 20)),
                            title: Text(recipe['title'], style: TextStyle(fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black87)),
                            onTap: () => setState(() { _selectedRecipeId = recipe['id']; _selectedRecipeTitle = recipe['title']; _titleController.text = recipe['title']; _recipeSearchResults.clear(); _recipeSearchController.clear(); }),
                          );
                        },
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernTextField({required TextEditingController controller, required String hint, bool enabled = true, int maxLines = 1, required bool isDarkMode, IconData? prefixIcon, Widget? suffixWidget, Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade500) : null,
          suffixIcon: suffixWidget != null ? Padding(padding: const EdgeInsets.all(12), child: suffixWidget) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: enabled ? (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50) : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        hint: Text('Pilih Kategori', style: TextStyle(color: Colors.grey.shade500)),
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), filled: true, fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        items: _categories.map((String category) {
          IconData icon = category == 'Makanan' ? Icons.restaurant_rounded : category == 'Minuman' ? Icons.local_cafe_rounded : Icons.menu_book_rounded;
          return DropdownMenuItem<String>(value: category, child: Row(children: [Icon(icon, size: 18, color: Colors.orange), const SizedBox(width: 10), Text(category)]));
        }).toList(),
        onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
      ),
    );
  }


  void _showMediaPicker(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Pilih Media',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Photo Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.photo_rounded, size: 16, color: Colors.blue.shade400),
                        const SizedBox(width: 6),
                        Text('Foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMediaOptionTile(
                          icon: Icons.camera_alt_rounded,
                          label: lang.getText('upload_camera'),
                          gradient: const [Color(0xFF3498DB), Color(0xFF2980B9)],
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMediaOptionTile(
                          icon: Icons.photo_library_rounded,
                          label: lang.getText('upload_gallery'),
                          gradient: const [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Video Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.videocam_rounded, size: 16, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Text('Video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMediaOptionTile(
                          icon: Icons.videocam_rounded,
                          label: 'Rekam Video',
                          gradient: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickVideo(ImageSource.camera);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMediaOptionTile(
                          icon: Icons.video_library_rounded,
                          label: 'Dari Galeri',
                          gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickVideo(ImageSource.gallery);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOptionTile({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final File videoFile;

  const _VideoPreviewDialog({required this.videoFile});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.file(widget.videoFile);
    await _videoPlayerController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_chewieController != null && _videoPlayerController.value.isInitialized)
            AspectRatio(
              aspectRatio: _videoPlayerController.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}