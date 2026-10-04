import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contribution_screen.dart';
import 'home_screen.dart';

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

  static const navy = Color(0xFF16233D);
  static const green = Color(0xFF007A5E);
  static const orange = Color(0xFFAA5B00);
  static const background = Color(0xFFF6F8FD);

  Uint8List? imageBytes;

  bool checkingDuplicate = true;
  bool submitting = false;

  List<Map<String, dynamic>> similarReports = [];

  @override
  void initState() {
    super.initState();

    _loadImage();
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

  // ==========================================================
  // DISTANCE CALCULATION
  // ==========================================================

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
      return '${meters.round()}m away';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  // ==========================================================
  // DUPLICATE DETECTION
  // ==========================================================

  Future<void> _checkForDuplicates() async {
    try {
      /*
       * Get reports with the same category.
       *
       * We don't compare every report in the system.
       * Only reports from the same category are considered.
       */

      final response = await supabase
          .from('reports')
          .select(
            'id, title, category, description, '
            'image_url, latitude, longitude, status, created_at',
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

        /*
         * 500 meter duplicate detection radius.
         */

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

  // ==========================================================
  // UPLOAD IMAGE
  // ==========================================================

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

  // ==========================================================
  // FINAL REPORT SUBMISSION
  // ==========================================================

  Future<void> _submitNewReport() async {
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
        SnackBar(content: Text('Failed to submit report: ${error.message}')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  // ==========================================================
  // SUCCESS
  // ==========================================================

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
                'Your civic issue has been successfully submitted.',
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

  // ==========================================================
  // REVIEW ITEM
  // ==========================================================

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

  // ==========================================================
  // SIMILAR REPORT CARD
  // ==========================================================

  Widget _similarReportCard(Map<String, dynamic> report) {
    final imageUrl = report['image_url'] as String?;

    final distance = report['distance'] as double;

    final title = report['title']?.toString() ?? 'Civic Issue';

    final description = report['description']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                child: const Text(
                  'In Progress',
                  style: TextStyle(
                    color: Color(0xFF176B9E),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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
                child: imageUrl != null && imageUrl.isNotEmpty
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
                      widget.category,
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

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showFullReport(report);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('View Full Report'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _openContribution(report);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Contribute'),
                ),
              ),
            ],
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

  // ==========================================================
  // FULL REPORT
  // ==========================================================

  void _showFullReport(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
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

                if (report['image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      report['image_url'],
                      width: double.infinity,
                      height: 210,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 18),

                Text(
                  report['title']?.toString() ?? '',
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
                  _formatDistance(report['distance'] as double),
                  icon: Icons.location_on_outlined,
                ),

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

  // ==========================================================
  // OPEN CONTRIBUTION
  // ==========================================================

  void _openContribution(Map<String, dynamic> report) {
    final reportId = report['id']?.toString();

    if (reportId == null) {
      return;
    }

    final distance = report['distance'] as double;

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

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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

                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Progress
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
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

                    // PHOTO
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

                    _reviewItem(
                      'Location',
                      '${widget.latitude.toStringAsFixed(6)}, '
                          '${widget.longitude.toStringAsFixed(6)}',
                      icon: Icons.location_on_outlined,
                    ),

                    const SizedBox(height: 5),

                    // EDIT
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

                    // DUPLICATE SECTION
                    if (checkingDuplicate)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: green,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Checking for similar reports nearby...',
                                style: TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (similarReports.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                      'Similar Reports Found Nearby',
                                      style: TextStyle(
                                        color: navy,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
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

                          const SizedBox(height: 15),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Text(
                              'Instead of creating a duplicate report, you can contribute additional evidence to an existing report.',
                              style: TextStyle(
                                color: Color(0xFF475467),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          ...similarReports.map(_similarReportCard),

                          const SizedBox(height: 10),

                          // Still allow new report
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: submitting ? null : _submitNewReport,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: navy,
                                side: const BorderSide(color: navy),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(27),
                                ),
                              ),
                              child: const Text(
                                'Submit as New Report',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: green,
                              size: 38,
                            ),

                            const SizedBox(height: 10),

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
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 17),

                            SizedBox(
                              width: double.infinity,
                              height: 53,
                              child: ElevatedButton(
                                onPressed: submitting ? null : _submitNewReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(27),
                                  ),
                                ),
                                child: submitting
                                    ? const SizedBox(
                                        width: 23,
                                        height: 23,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Confirm & Submit Report',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
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
