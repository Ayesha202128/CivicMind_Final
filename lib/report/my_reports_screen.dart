import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_details_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  final supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allReports = [];
  List<Map<String, dynamic>> filteredReports = [];

  String selectedFilter = 'All';

  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);

    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please sign in to view your reports.');
      }

      final data = await supabase
          .from('reports')
          .select(
            'id, title, category, description, status, '
            'created_at, updated_at, image_url, latitude, longitude',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final reports = List<Map<String, dynamic>>.from(data);

      final contributionData = await supabase
          .from('report_contributions')
          .select('report_id');

      final Map<String, int> contributionCounts = {};

      for (final row in contributionData) {
        final reportId = row['report_id']?.toString();

        if (reportId == null || reportId.isEmpty) {
          continue;
        }

        contributionCounts[reportId] = (contributionCounts[reportId] ?? 0) + 1;
      }

      for (final report in reports) {
        final reportId = report['id']?.toString();

        report['contribution_count'] = contributionCounts[reportId] ?? 0;
      }

      if (!mounted) return;

      allReports = reports;

      _applyFilters();

      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint('MY REPORTS ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyFilters() {
    final searchText = _searchController.text.trim().toLowerCase();

    List<Map<String, dynamic>> result = List.from(allReports);

    if (selectedFilter != 'All') {
      result = result.where((report) {
        final status = report['status']?.toString().toLowerCase() ?? '';

        switch (selectedFilter) {
          case 'Pending':
            return status == 'new' || status == 'pending';

          case 'In Progress':
            return status == 'in_progress' || status == 'in progress';

          case 'Resolved':
            return status == 'resolved';

          default:
            return true;
        }
      }).toList();
    }

    if (searchText.isNotEmpty) {
      result = result.where((report) {
        final title = report['title']?.toString().toLowerCase() ?? '';

        final category = report['category']?.toString().toLowerCase() ?? '';

        return title.contains(searchText) || category.contains(searchText);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      filteredReports = result;
    });
  }

  String _statusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
      case 'pending':
        return 'Pending';

      case 'in_progress':
      case 'in progress':
        return 'In Progress';

      case 'resolved':
        return 'Resolved';

      default:
        return 'Pending';
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
        return Colors.green;

      case 'in_progress':
      case 'in progress':
        return Colors.blue;

      case 'new':
      case 'pending':
      default:
        return orange;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

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

      return '$day/$month/$year • '
          '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final category = report['category']?.toString() ?? 'Unknown';

    final title = report['title']?.toString() ?? 'Untitled Report';

    final status = report['status']?.toString() ?? 'new';

    final imageUrl = report['image_url']?.toString();

    final statusText = _statusText(status);

    final statusColor = _statusColor(status);

    final contributionCount =
        (report['contribution_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailsScreen(report: report),
            ),
          );
          if (updated == true && mounted) {
            _loadReports();
          }
        },

        child: Padding(
          padding: const EdgeInsets.all(13),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),

                child: SizedBox(
                  width: 82,
                  height: 82,

                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder();
                          },
                        )
                      : _imagePlaceholder(),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Expanded(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.black45,
                        ),

                        const SizedBox(width: 4),

                        Expanded(
                          child: Text(
                            _formatDate(report['created_at']?.toString()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.black45,
                        ),

                        const SizedBox(width: 4),

                        Text(
                          '$contributionCount '
                          'contribution'
                          '${contributionCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey, size: 30),
      ),
    );
  }

  Widget _filterButton(String title) {
    final isSelected = selectedFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = title;
        });

        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),

        decoration: BoxDecoration(
          color: isSelected ? navy : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? navy : Colors.grey.shade300),
        ),

        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : navy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80, left: 30, right: 30),

        child: Column(
          children: [
            Icon(Icons.search_off, size: 65, color: Colors.grey.shade400),

            const SizedBox(height: 15),

            Text(
              selectedFilter == 'All'
                  ? 'No reports found'
                  : 'No $selectedFilter reports',

              style: const TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              _searchController.text.trim().isNotEmpty
                  ? 'Try a different title or category.'
                  : 'There are no reports in this category yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),

        title: const Text(
          'My Report Issues',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _loadReports,
            icon: const Icon(Icons.refresh, color: navy),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReports,

          child: loading
              ? const Center(child: CircularProgressIndicator(color: orange))
              : errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),

                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                        ),

                        child: TextField(
                          controller: _searchController,

                          textInputAction: TextInputAction.search,

                          decoration: InputDecoration(
                            hintText: 'Search by title or category',

                            hintStyle: const TextStyle(
                              color: Colors.black38,
                              fontSize: 13,
                            ),

                            prefixIcon: const Icon(Icons.search, color: navy),

                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyFilters();
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.black45,
                                    ),
                                  )
                                : null,

                            border: InputBorder.none,

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 43,

                      child: ListView(
                        scrollDirection: Axis.horizontal,

                        padding: const EdgeInsets.symmetric(horizontal: 16),

                        children: [
                          _filterButton('All'),

                          const SizedBox(width: 8),

                          _filterButton('Pending'),

                          const SizedBox(width: 8),

                          _filterButton('In Progress'),

                          const SizedBox(width: 8),

                          _filterButton('Resolved'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      child: Row(
                        children: [
                          Text(
                            '${filteredReports.length} '
                            'report'
                            '${filteredReports.length == 1 ? '' : 's'}',

                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const Spacer(),

                          if (selectedFilter != 'All')
                            Text(
                              selectedFilter,
                              style: const TextStyle(
                                color: navy,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: filteredReports.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [_buildNoResult()],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: filteredReports.length,
                              itemBuilder: (context, index) {
                                return _buildReportCard(filteredReports[index]);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.35),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(25),

            child: Column(
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),

                const SizedBox(height: 14),

                Text(
                  errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: navy, fontSize: 15),
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: _loadReports,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                  ),

                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
