import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_report_screen.dart';

class ReportDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const ReportDetailsScreen({super.key, required this.report});

  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  // ==========================================================
  // STATUS TEXT
  // ==========================================================

  String _statusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
      case 'pending':
        return 'Pending';

      case 'under_review':
      case 'under review':
        return 'Under Review';

      case 'assigned':
        return 'Assigned';

      case 'in_progress':
      case 'in progress':
        return 'In Progress';

      case 'resolved':
        return 'Resolved';

      default:
        return 'Pending';
    }
  }

  // ==========================================================
  // STATUS COLOR
  // ==========================================================

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
        return Colors.green;

      case 'in_progress':
      case 'in progress':
        return Colors.blue;

      case 'assigned':
        return Colors.deepPurple;

      case 'under_review':
      case 'under review':
        return Colors.orange;

      case 'new':
      case 'pending':
      default:
        return orange;
    }
  }

  // ==========================================================
  // DATE FORMAT
  // ==========================================================

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;

      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');

      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;

      if (hour == 0) {
        hour = 12;
      }

      return '$day/$month/$year • $hour:$minute $period';
    } catch (e) {
      return 'Unknown';
    }
  }

  // ==========================================================
  // OPEN LOCATION
  // ==========================================================

  Future<void> _openLocation(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$latitude,$longitude',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the map.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
    }
  }

  // ==========================================================
  // STATUS PROGRESS
  // ==========================================================

  int _statusIndex(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
      case 'pending':
        return 0;

      case 'under_review':
      case 'under review':
        return 1;

      case 'assigned':
        return 2;

      case 'in_progress':
      case 'in progress':
        return 3;

      case 'resolved':
        return 4;

      default:
        return 0;
    }
  }

  // ==========================================================
  // STATUS TIMELINE ITEM
  // ==========================================================

  Widget _timelineItem({
    required String title,
    required String description,
    required bool completed,
    required bool current,
    required bool last,
  }) {
    final color = completed || current ? orange : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: completed || current ? orange : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: completed || current
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              if (!last) Container(width: 2, height: 52, color: color),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: completed || current ? navy : Colors.black45,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: completed || current
                        ? Colors.black54
                        : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STATUS TIMELINE
  // ==========================================================

  Widget _buildStatusTimeline(String status) {
    final currentIndex = _statusIndex(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Status',
            style: TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          _timelineItem(
            title: 'Report Submitted',
            description: 'Your report has been submitted.',
            completed: currentIndex >= 0,
            current: currentIndex == 0,
            last: false,
          ),

          _timelineItem(
            title: 'Under Review',
            description: 'The report is being reviewed.',
            completed: currentIndex >= 1,
            current: currentIndex == 1,
            last: false,
          ),

          _timelineItem(
            title: 'Assigned',
            description: 'The issue is assigned to the responsible authority.',
            completed: currentIndex >= 2,
            current: currentIndex == 2,
            last: false,
          ),

          _timelineItem(
            title: 'In Progress',
            description: 'Work on the reported issue is in progress.',
            completed: currentIndex >= 3,
            current: currentIndex == 3,
            last: false,
          ),

          _timelineItem(
            title: 'Resolved',
            description: 'The reported issue has been resolved.',
            completed: currentIndex >= 4,
            current: currentIndex == 4,
            last: true,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LOCATION MAP
  // ==========================================================

  Widget _buildMap(BuildContext context, double latitude, double longitude) {
    final point = LatLng(latitude, longitude);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.civicmind',
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: orange,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: () {
                _openLocation(context, latitude, longitude);
              },
              icon: const Icon(Icons.directions, color: Colors.white),
              label: const Text(
                'Open in Google Maps',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INFO ROW
  // ==========================================================

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: orange, size: 19),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 14,
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
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final title = report['title']?.toString() ?? 'Untitled Report';

    final category = report['category']?.toString() ?? 'Unknown';

    final description = report['description']?.toString() ?? '';

    final status = report['status']?.toString() ?? 'new';

    final imageUrl = report['image_url']?.toString();

    final latitude = (report['latitude'] as num?)?.toDouble();

    final longitude = (report['longitude'] as num?)?.toDouble();

    final statusText = _statusText(status);
    final statusColor = _statusColor(status);

    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,

        iconTheme: const IconThemeData(color: navy),

        title: const Text(
          'Report Details',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: 'Edit Report',

            icon: const Icon(Icons.edit_outlined, color: navy),

            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditReportScreen(report: report),
                ),
              );

              if (updated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 25),
          children: [
            // ==================================================
            // REPORT IMAGE
            // ==================================================
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _imagePlaceholder();
                  },
                ),
              )
            else
              _imagePlaceholder(),

            const SizedBox(height: 16),

            // ==================================================
            // TITLE + STATUS
            // ==================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          color: orange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        title,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ==================================================
            // DESCRIPTION
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Text(
                    description.isEmpty
                        ? 'No description provided.'
                        : description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // REPORT INFORMATION
            // ==================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Information',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 17),

                  _infoRow(Icons.category_outlined, 'Category', category),

                  _infoRow(
                    Icons.access_time,
                    'Reported',
                    _formatDate(report['created_at']?.toString()),
                  ),

                  _infoRow(
                    Icons.update,
                    'Last Updated',
                    _formatDate(report['updated_at']?.toString()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // STATUS TIMELINE
            // ==================================================
            _buildStatusTimeline(status),

            // ==================================================
            // LOCATION
            // ==================================================
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reported Location',
                      style: TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildMap(context, latitude, longitude),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(Icons.location_on, color: orange, size: 18),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            '${latitude.toStringAsFixed(6)}, '
                            '${longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // IMAGE PLACEHOLDER
  // ==========================================================

  Widget _imagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 55),
      ),
    );
  }
}
