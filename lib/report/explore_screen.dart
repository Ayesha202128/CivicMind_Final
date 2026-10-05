import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  final supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  bool loading = true;

  List<Map<String, dynamic>> reports = [];

  String selectedFilter = "All";

  final List<String> filters = [
    "All",
    "Pothole",
    "Garbage",
    "Streetlight",
    "Water Leak",
    "Fallen Tree",
  ];

  @override
  void initState() {
    super.initState();

    _loadReports();

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final data = await supabase
          .from('reports')
          .select(
            'id, user_id, title, category, description, '
            'status, created_at, updated_at, image_url, '
            'latitude, longitude',
          )
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;

      setState(() {
        reports = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      debugPrint("EXPLORE ERROR: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not load reports.")));
    }
  }

  List<Map<String, dynamic>> get filteredReports {
    final searchText = _searchController.text.trim().toLowerCase();

    return reports.where((report) {
      bool matchesCategory = true;

      if (selectedFilter != "All") {
        final category = report['category']?.toString().toLowerCase() ?? '';

        matchesCategory = category == selectedFilter.toLowerCase();
      }

      if (!matchesCategory) {
        return false;
      }

      if (searchText.isEmpty) {
        return true;
      }

      final title = report['title']?.toString().toLowerCase() ?? '';

      final category = report['category']?.toString().toLowerCase() ?? '';

      final description = report['description']?.toString().toLowerCase() ?? '';

      final status = report['status']?.toString().toLowerCase() ?? '';

      final reportId = report['id']?.toString().toLowerCase() ?? '';

      return title.contains(searchText) ||
          category.contains(searchText) ||
          description.contains(searchText) ||
          status.contains(searchText) ||
          reportId.contains(searchText);
    }).toList();
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null) return "";

    final date = DateTime.tryParse(dateString);

    if (date == null) return "";

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) {
      return "Just now";
    }

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    }

    if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    }

    if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    }

    return "${date.day}/${date.month}/${date.year}";
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();

    if (value.contains("pothole")) {
      return Icons.warning_amber_rounded;
    }

    if (value.contains("garbage")) {
      return Icons.delete_outline_rounded;
    }

    if (value.contains("street")) {
      return Icons.lightbulb_outline_rounded;
    }

    if (value.contains("water")) {
      return Icons.water_drop_outlined;
    }

    if (value.contains("tree")) {
      return Icons.park_outlined;
    }

    return Icons.report_problem_outlined;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "resolved":
        return Colors.green;

      case "in progress":
      case "in_progress":
        return Colors.orange;

      case "rejected":
        return Colors.red;

      default:
        return navy;
    }
  }

  String _formatStatus(String status) {
    if (status.toLowerCase() == "in_progress") {
      return "IN PROGRESS";
    }

    return status.toUpperCase();
  }

  void _openReportDetails(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportDetailsScreen(report: report)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleReports = filteredReports;

    return RefreshIndicator(
      color: orange,
      onRefresh: _loadReports,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: bg,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,

            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      "C",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                const Text(
                  "Explore",
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 21,
                  ),
                ),
              ],
            ),

            actions: [
              IconButton(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh_rounded, color: navy),
              ),
              const SizedBox(width: 5),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Community Reports",
                    style: TextStyle(
                      color: navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "See what is happening in your community.",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.grey),

                        const SizedBox(width: 10),

                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search civic issues...",
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.search,
                          ),
                        ),

                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final filter = filters[index];

                        final selected = filter == selectedFilter;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedFilter = filter;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: selected ? orange : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? orange : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: selected ? Colors.white : navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (_searchController.text.isNotEmpty)
                    Text(
                      "${visibleReports.length} result(s) found",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: orange)),
            )
          else if (visibleReports.isEmpty)
            SliverFillRemaining(child: _buildEmptyFeed())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 25),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final report = visibleReports[index];

                  return _buildReportCard(report);
                }, childCount: visibleReports.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final title = report['title']?.toString() ?? "Civic Issue";

    final category = report['category']?.toString() ?? "Other";

    final description = report['description']?.toString() ?? "";

    final status = report['status']?.toString() ?? "new";

    final imageUrl = report['image_url']?.toString();

    final createdAt = report['created_at']?.toString();

    final hasLocation =
        report['latitude'] != null && report['longitude'] != null;

    return GestureDetector(
      onTap: () {
        _openReportDetails(report);
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: navy.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: navy,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CivicMind Citizen",
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          _getTimeAgo(createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _imagePlaceholder();
                    },
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(color: orange),
                        ),
                      );
                    },
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: orange.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _categoryIcon(category),
                          color: orange,
                          size: 19,
                        ),
                      ),

                      const SizedBox(width: 9),

                      Text(
                        category,
                        style: const TextStyle(
                          color: orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (hasLocation)
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "Location attached",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  const Divider(height: 1),

                  const SizedBox(height: 7),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        _openReportDetails(report);
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text("View Report"),
                      style: TextButton.styleFrom(foregroundColor: navy),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      height: 180,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildEmptyFeed() {
    final searching = _searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: orange.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: orange,
                size: 40,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              searching ? "No matching reports" : "No reports found",
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              searching
                  ? "Try another keyword or category."
                  : "There are no civic reports in this category yet.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
