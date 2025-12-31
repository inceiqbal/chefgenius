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

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('upload_title')),
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _uploadPost,
            icon: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
              : const Icon(Icons.send, color: Colors.orange),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Media Preview Area (Carousel)
            if (_mediaItems.isEmpty)
              GestureDetector(
                onTap: () => _showMediaPicker(context),
                child: Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(lang.getText('upload_tap_hint'), style: const TextStyle(color: Colors.grey)),
                      const Text("(Maksimal 10 Slide)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: _mediaItems.length,
                      itemBuilder: (context, index) {
                        final item = _mediaItems[index];
                        final file = item['file'] as File;
                        final type = item['type'] as String;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                                          const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
                                        ],
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: () => _removeMedia(index),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${index + 1}/${_mediaItems.length}",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_mediaItems.length < 10)
                    TextButton.icon(
                      onPressed: () => _showMediaPicker(context),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Tambah Slide"),
                    ),
                ],
              ),

            const SizedBox(height: 20),
            
            // OPSI RECOOK (HASIL MASAK DARI RESEP APLIKASI)
            CheckboxListTile(
              title: const Text("Ini hasil masak dari resep ChefGenius?"),
              value: _isRecook,
              onChanged: (val) {
                setState(() {
                  _isRecook = val ?? false;
                  if (!_isRecook) {
                    _selectedRecipeId = null;
                    _selectedRecipeTitle = null;
                    _recipeSearchController.clear();
                    _titleController.clear();
                  } else {
                    _titleController.clear();
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            if (_isRecook) ...[
              if (_selectedRecipeTitle != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Resep: $_selectedRecipeTitle",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedRecipeId = null;
                            _selectedRecipeTitle = null;
                            _titleController.clear();
                          });
                        },
                      )
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _recipeSearchController,
                      decoration: InputDecoration(
                        hintText: "Cari nama resep...",
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isSearchingRecipe 
                            ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) 
                            : null,
                      ),
                      onChanged: (val) {
                        if (val.length > 2) _searchRecipes(val);
                      },
                    ),
                    if (_recipeSearchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        margin: const EdgeInsets.only(top: 4, bottom: 16),
                        decoration: BoxDecoration(
                          // FIX: Tambahkan background color yang sesuai dark mode
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _recipeSearchResults.length,
                          itemBuilder: (context, index) {
                            final recipe = _recipeSearchResults[index];
                            return ListTile(
                              title: Text(recipe['title']),
                              onTap: () {
                                setState(() {
                                  _selectedRecipeId = recipe['id'];
                                  _selectedRecipeTitle = recipe['title'];
                                  _titleController.text = recipe['title'];
                                  _recipeSearchResults.clear();
                                  _recipeSearchController.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],

            // Input Judul Hidangan
            TextField(
              controller: _titleController,
              enabled: !_isRecook,
              decoration: InputDecoration(
                labelText: "Judul Hidangan",
                hintText: "Misal: Nasi Goreng Spesial",
                border: const OutlineInputBorder(),
                filled: _isRecook,
                fillColor: _isRecook 
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]) 
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Input Caption
            TextField(
              controller: _captionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: lang.getText('upload_caption_hint'),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown Kategori
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text("Pilih Kategori"),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              validator: (value) => value == null ? 'Harap pilih kategori' : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaPicker(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(lang.getText('upload_camera')),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(lang.getText('upload_gallery')),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: const Text("Ambil Video"),
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text("Pilih Video dari Galeri"),
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo(ImageSource.gallery);
            },
          ),
        ],
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