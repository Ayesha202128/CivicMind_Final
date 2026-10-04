import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditReportScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const EditReportScreen({super.key, required this.report});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  final supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _descriptionController = TextEditingController();

  final List<String> categories = [
    'Pothole',
    'Garbage',
    'Electric Hazard',
    'Fallen Tree',
    'Water Leak',
  ];

  String? selectedCategory;
  String? errorMessage;

  bool saving = false;
  bool changingImage = false;

  // নতুন ছবির file এবং তার bytes
  XFile? newImage;
  Uint8List? newImageBytes;

  @override
  void initState() {
    super.initState();

    _titleController.text = widget.report['title']?.toString() ?? '';

    _descriptionController.text =
        widget.report['description']?.toString() ?? '';

    final existingCategory = widget.report['category']?.toString();

    if (existingCategory != null && categories.contains(existingCategory)) {
      selectedCategory = existingCategory;
    } else {
      selectedCategory = categories.first;
    }
  }

  // ==========================================================
  // PICK NEW PHOTO
  // ==========================================================

  Future<void> _pickNewImage() async {
    if (saving || changingImage) return;

    setState(() {
      changingImage = true;
      errorMessage = null;
    });

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      // Select করার পরই bytes load করছি
      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      if (bytes.isEmpty) {
        setState(() {
          errorMessage = 'Selected photo is empty. Please choose another.';
        });
        return;
      }

      setState(() {
        newImage = picked;
        newImageBytes = bytes;
      });
    } catch (e) {
      debugPrint('PICK IMAGE ERROR: $e');

      if (!mounted) return;

      setState(() {
        errorMessage = 'Could not load the selected photo. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          changingImage = false;
        });
      }
    }
  }

  // ==========================================================
  // UPDATE REPORT
  // ==========================================================

  Future<void> _updateReport() async {
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a report title.';
      });
      return;
    }

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      setState(() {
        errorMessage = 'Please select a category.';
      });
      return;
    }

    if (description.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a description.';
      });
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        errorMessage = 'Please sign in again.';
      });
      return;
    }

    final reportId = widget.report['id']?.toString();

    if (reportId == null || reportId.isEmpty) {
      setState(() {
        errorMessage = 'Report ID is missing.';
      });
      return;
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      // আগের ছবির URL রাখছি
      String? imageUrl = widget.report['image_url']?.toString();

      // নতুন ছবি select করা থাকলেই upload হবে
      if (newImage != null && newImageBytes != null) {
        final fileName = newImage!.name;
        final dotIndex = fileName.lastIndexOf('.');

        final extension = dotIndex >= 0
            ? fileName.substring(dotIndex + 1).toLowerCase()
            : 'jpg';

        final safeExtension = extension.isEmpty ? 'jpg' : extension;

        final filePath =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

        final contentType =
            newImage!.mimeType ??
            (safeExtension == 'png'
                ? 'image/png'
                : safeExtension == 'webp'
                ? 'image/webp'
                : 'image/jpeg');

        await supabase.storage
            .from('report-images')
            .uploadBinary(
              filePath,
              newImageBytes!,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            );

        imageUrl = supabase.storage
            .from('report-images')
            .getPublicUrl(filePath);
      }

      // Report update
      await supabase
          .from('reports')
          .update({
            'title': title,
            'category': selectedCategory,
            'description': description,
            'image_url': imageUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reportId)
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // আগের screen-এ true return
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('UPDATE REPORT ERROR: $e');

      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ==========================================================
  // IMAGE PREVIEW
  // ==========================================================

  Widget _buildImagePreview() {
    // নতুন ছবি select করা থাকলে সেটাই দেখাবে
    if (newImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          newImageBytes!,
          key: ValueKey(newImage!.path),
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _imagePlaceholder(
              message: 'Could not display selected photo',
            );
          },
        ),
      );
    }

    // নতুন ছবি না থাকলে existing image দেখাবে
    final imageUrl = widget.report['image_url']?.toString();

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          imageUrl,
          key: ValueKey(imageUrl),
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _imagePlaceholder(message: 'Could not load existing photo');
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;

            return Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: orange),
              ),
            );
          },
        ),
      );
    }

    return _imagePlaceholder(message: 'No photo available');
  }

  Widget _imagePlaceholder({String message = 'No photo'}) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 52, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      prefixIcon: Icon(icon, color: navy, size: 21),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: navy,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          'Edit Report',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update your report',
                style: TextStyle(
                  color: navy,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'You can update the information of your report.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 18),

              // PHOTO PREVIEW
              _buildImagePreview(),

              const SizedBox(height: 10),

              // CHANGE PHOTO
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: saving || changingImage ? null : _pickNewImage,
                  icon: changingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: navy,
                          ),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    changingImage
                        ? 'Loading Photo...'
                        : newImage != null
                        ? 'Change Photo Again'
                        : 'Change Photo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: const BorderSide(color: navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ERROR
              if (errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // TITLE
              _fieldLabel('Report Title'),
              const SizedBox(height: 7),
              TextField(
                controller: _titleController,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  hintText: 'Enter report title',
                  icon: Icons.title,
                ),
              ),

              const SizedBox(height: 16),

              // CATEGORY
              _fieldLabel('Category'),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: _inputDecoration(
                  hintText: 'Select category',
                  icon: Icons.category_outlined,
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
              ),

              const SizedBox(height: 16),

              // DESCRIPTION
              _fieldLabel('Description'),
              const SizedBox(height: 7),
              TextField(
                controller: _descriptionController,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 6,
                maxLength: 500,
                decoration: _inputDecoration(
                  hintText: 'Describe the civic problem...',
                  icon: Icons.description_outlined,
                ).copyWith(alignLabelWithHint: true),
              ),

              const SizedBox(height: 10),

              // NOTE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: navy, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Report status and report date cannot '
                        'be changed by citizens.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // SAVE CHANGES
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: saving || changingImage ? null : _updateReport,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    saving ? 'Saving Changes...' : 'Save Changes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // CANCEL
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: saving || changingImage
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: const BorderSide(color: navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
