import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contribution_screen.dart';
import '../home_screen.dart';

class ReportReviewScreen extends StatefulWidget {
  final XFile selectedImage;
  final double latitude;
  final double longitude;

  final String title;
  final String category;
  final String description;

  const ReportReviewScreen({
    super.key,
    required this.selectedImage,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.category,
    required this.description,
  });

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  final supabase = Supabase.instance.client;

  final Geocoding _geocoding = Geocoding();

  static const navy = Color(0xFF16233D);
  static const green = Color(0xFF007A5E);
  static const orange = Color(0xFFAA5B00);
  static const background = Color(0xFFF6F8FD);

  Uint8List? imageBytes;

  String locationText = 'Finding location...';
  bool loadingLocation = true;

  bool checkingDuplicate = true;

  List<Map<String, dynamic>> similarReports = [];

  bool submitting = false;

  @override
  void initState() {
    super.initState();

    _loadImage();
    _loadAddress();
    _checkForDuplicates();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.selectedImage.readAsBytes();

      if (!mounted) return;

      setState(() {
        imageBytes = bytes;
      });
    } catch (e) {
      debugPrint('IMAGE LOAD ERROR: $e');
    }
  }

  bool _isPlusCode(String value) {
    final text = value.trim();

    return RegExp(
      r'^[23456789CFGHJMPQRVWX]{4,}\+',
    ).hasMatch(text.toUpperCase());
  }

  bool _isSameAsAny(String value, List<String> parts) {
    final target = value.trim().toLowerCase();

    return parts.any((part) => part.trim().toLowerCase() == target);
  }

  Future<void> _loadAddress() async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        widget.latitude,
        widget.longitude,
      );

      if (placemarks.isEmpty) {
        if (!mounted) return;

        setState(() {
          locationText = 'Location address unavailable';
          loadingLocation = false;
        });

        return;
      }

      Placemark place = placemarks.first;

      for (final p in placemarks) {
        final road = p.thoroughfare?.trim();

        if (road != null && road.isNotEmpty && !_isPlusCode(road)) {
          place = p;
          break;
        }
      }

      final List<String> parts = [];

      void addPart(String? value) {
        if (value == null) return;

        final text = value.trim();

        if (text.isEmpty) return;

        if (_isPlusCode(text)) return;

        final alreadyExists = parts.any(
          (existing) => existing.toLowerCase() == text.toLowerCase(),
        );

        if (!alreadyExists) {
          parts.add(text);
        }
      }

      final houseNumber = place.subThoroughfare?.trim();
      final roadName = place.thoroughfare?.trim();

      if (houseNumber != null &&
          houseNumber.isNotEmpty &&
          roadName != null &&
          roadName.isNotEmpty &&
          !_isPlusCode(roadName)) {
        addPart('$houseNumber $roadName');
      } else {
        addPart(roadName);

        if (roadName == null || roadName.isEmpty) {
          addPart(place.street);
        }
      }

      addPart(place.subLocality);

      addPart(place.locality);

      addPart(place.country);

      final address = parts.join(', ');

      if (!mounted) return;

      setState(() {
        locationText = address.isEmpty
            ? 'Location address unavailable'
            : address;

        loadingLocation = false;
      });
    } catch (e) {
      debugPrint('ADDRESS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        locationText = 'Location address unavailable';
        loadingLocation = false;
      });
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;

    final dLat = _degreesToRadians(lat2 - lat1);

    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m away';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _checkForDuplicates() async {
    try {
      final response = await supabase
          .from('reports')
          .select(
            'id, title, category, description, '
            'image_url, latitude, longitude, '
            'status, created_at',
          )
          .eq('category', widget.category)
          .neq('status', 'resolved')
          .order('created_at', ascending: false)
          .limit(100);

      final List<Map<String, dynamic>> matches = [];

      for (final item in response) {
        final latitude = item['latitude'];
        final longitude = item['longitude'];

        if (latitude == null || longitude == null) {
          continue;
        }

        final double reportLat = (latitude as num).toDouble();

        final double reportLng = (longitude as num).toDouble();

        final distance = _calculateDistance(
          widget.latitude,
          widget.longitude,
          reportLat,
          reportLng,
        );

        if (distance <= 500) {
          final report = Map<String, dynamic>.from(item);

          report['distance'] = distance;

          matches.add(report);
        }
      }

      matches.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (!mounted) return;

      setState(() {
        similarReports = matches.take(3).toList();

        checkingDuplicate = false;
      });
    } catch (e) {
      debugPrint('DUPLICATE DETECTION ERROR: $e');

      if (!mounted) return;

      setState(() {
        checkingDuplicate = false;
        similarReports = [];
      });
    }
  }

  Future<String> _uploadImage() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final bytes = await widget.selectedImage.readAsBytes();

    final filePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('report-images')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return supabase.storage.from('report-images').getPublicUrl(filePath);
  }

  Future<void> _submitNewReport() async {
    if (similarReports.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A similar report already exists. '
            'Please contribute to it instead.',
          ),
        ),
      );

      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in again.')));

      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      final imageUrl = await _uploadImage();

      await supabase.from('reports').insert({
        'user_id': user.id,
        'title': widget.title,
        'category': widget.category,
        'description': widget.description,
        'image_url': imageUrl,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
      });

      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      _showSuccessDialog();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit report: '
            '${error.message}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('REPORT SUBMISSION ERROR: $e');

      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F4EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: green, size: 48),
              ),

              const SizedBox(height: 20),

              const Text(
                'Report Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: navy,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Your civic issue has been '
                'successfully submitted.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reviewItem(String label, String value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5F1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: green, size: 20),
            ),

          if (icon != null) const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _similarReportCard(Map<String, dynamic> report) {
    final imageUrl = report['image_url']?.toString() ?? '';

    final distance = (report['distance'] as num?)?.toDouble() ?? 0.0;

    final title = report['title']?.toString() ?? 'Civic Issue';

    final description = report['description']?.toString() ?? '';

    final status = report['status']?.toString() ?? 'new';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF176B9E),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                _formatDistance(distance),
                style: const TextStyle(
                  color: green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 105,
                        height: 95,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _imagePlaceholder();
                        },
                      )
                    : _imagePlaceholder(),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['category']?.toString() ?? widget.category,
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                _showFullReport(report);
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text(
                'View Full Report',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
          ),

          const SizedBox(height: 9),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                _openContribution(report);
              },
              icon: const Icon(Icons.add_task_outlined, color: Colors.white),
              label: const Text(
                'Contribute to This Report',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 105,
      height: 95,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined, color: Colors.grey, size: 32),
    );
  }

  void _showFullReport(Map<String, dynamic> report) {
    final distance = (report['distance'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        final imageUrl = report['image_url']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'Existing Report',
                  style: TextStyle(
                    color: navy,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: double.infinity,
                          height: 210,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 45,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 18),

                Text(
                  report['title']?.toString() ?? 'Civic Issue',
                  style: const TextStyle(
                    color: navy,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                _reviewItem(
                  'Category',
                  report['category']?.toString() ?? '',
                  icon: Icons.category_outlined,
                ),

                _reviewItem(
                  'Status',
                  report['status']?.toString() ?? '',
                  icon: Icons.info_outline,
                ),

                _reviewItem(
                  'Distance',
                  _formatDistance(distance),
                  icon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 4),

                Text(
                  report['description']?.toString() ?? '',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);

                      _openContribution(report);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Contribute to This Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openContribution(Map<String, dynamic> report) {
    final reportId = report['id']?.toString();

    if (reportId == null || reportId.isEmpty) {
      return;
    }

    final distance = (report['distance'] as num?)?.toDouble() ?? 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContributionScreen(
          reportId: reportId,
          reportTitle: report['title']?.toString() ?? 'Civic Issue',
          reportCategory: report['category']?.toString() ?? widget.category,
          reportImageUrl: report['image_url']?.toString() ?? '',
          distanceText: _formatDistance(distance),
          userLatitude: widget.latitude,
          userLongitude: widget.longitude,
        ),
      ),
    );
  }

  Widget _buildDuplicateSection() {
    if (checkingDuplicate) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE5F5)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: green),
            ),

            SizedBox(width: 14),

            Expanded(
              child: Text(
                'Checking for similar reports nearby...',
                style: TextStyle(color: navy, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (similarReports.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1D4AE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3E8DC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: orange,
                    size: 29,
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Potential Duplicate Detected',
                        style: TextStyle(
                          color: navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'A similar civic issue has already been reported near this location.',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1D9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'To prevent duplicate reports, CivicMind will not create a new ticket for this issue. Please contribute evidence to the existing report instead.',
                style: TextStyle(
                  color: Color(0xFF694A1A),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 16),

            ...similarReports.map((report) => _similarReportCard(report)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC9EBDD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: green, size: 32),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Similar Report Found',
                  style: TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Your report appears to be a new civic issue.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, color: navy),
                  ),

                  const SizedBox(width: 3),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CIVICMIND',
                          style: TextStyle(
                            color: green,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),

                        SizedBox(height: 2),

                        Text(
                          'Incident Review',
                          style: TextStyle(
                            color: navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: const Icon(Icons.close, color: Color(0xFF344054)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'STEP 3 OF 4',
                        style: TextStyle(
                          color: green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        'Incident Review & Verification',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      value: 0.75,
                      minHeight: 7,
                      backgroundColor: Color(0xFFDCEFE9),
                      valueColor: AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Your Report',
                      style: TextStyle(
                        color: navy,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Please make sure everything is correct before submitting.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          imageBytes!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: green),
                        ),
                      ),

                    const SizedBox(height: 18),

                    _reviewItem(
                      'Issue Category',
                      widget.category,
                      icon: Icons.category_outlined,
                    ),

                    _reviewItem(
                      'Title',
                      widget.title,
                      icon: Icons.title_outlined,
                    ),

                    _reviewItem(
                      'Description',
                      widget.description,
                      icon: Icons.description_outlined,
                    ),

                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAF5F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: green,
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                loadingLocation
                                    ? const Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: green,
                                            ),
                                          ),

                                          SizedBox(width: 8),

                                          Text(
                                            'Finding address...',
                                            style: TextStyle(
                                              color: navy,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        locationText,
                                        style: const TextStyle(
                                          color: navy,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Go Back & Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: navy,
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Duplicate Check',
                      style: TextStyle(
                        color: navy,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'CivicMind checks whether a similar issue already exists near this location.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildDuplicateSection(),

                    const SizedBox(height: 28),

                    if (!checkingDuplicate && similarReports.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: submitting ? null : _submitNewReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: orange,
                            disabledBackgroundColor: Colors.grey.shade400,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Confirm & Submit Report',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                    if (!checkingDuplicate && similarReports.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1D9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: orange, size: 22),

                            SizedBox(width: 9),

                            Expanded(
                              child: Text(
                                'A new report cannot be submitted because a similar issue already exists. Please use “Contribute to This Report” above.',
                                style: TextStyle(
                                  color: Color(0xFF694A1A),
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
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
