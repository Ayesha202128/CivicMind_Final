import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contribution_success_screen.dart';

class ContributionScreen extends StatefulWidget {
  final String reportId;
  final String reportTitle;
  final String reportCategory;
  final String reportImageUrl;
  final String distanceText;

  final double? userLatitude;
  final double? userLongitude;

  const ContributionScreen({
    super.key,
    required this.reportId,
    required this.reportTitle,
    required this.reportCategory,
    required this.reportImageUrl,
    required this.distanceText,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final supabase = Supabase.instance.client;

  static const navy = Color(0xFF16233D);
  static const green = Color(0xFF007A5E);
  static const orange = Color(0xFFAA5B00);
  static const background = Color(0xFFF6F8FD);

  bool sameProblem = true;

  String locationRelation = 'few_meters_away';

  XFile? evidenceImage;
  Uint8List? evidenceBytes;

  final TextEditingController noteController = TextEditingController();

  bool submitting = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidencePhoto() async {
    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        evidenceImage = image;
        evidenceBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not select the photo.')),
      );
    }
  }

  Future<String?> _uploadEvidence() async {
    if (evidenceImage == null || evidenceBytes == null) {
      return null;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final filePath =
        '${user.id}/contributions/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('report-images')
        .uploadBinary(
          filePath,
          evidenceBytes!,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    return supabase.storage.from('report-images').getPublicUrl(filePath);
  }

  Future<void> _submitContribution() async {
    if (!sameProblem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please use a new report if this is a different issue.',
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
      final evidenceUrl = await _uploadEvidence();

      await supabase.from('report_contributions').insert({
        'report_id': widget.reportId,
        'user_id': user.id,
        'is_same_problem': true,
        'location_relation': locationRelation,
        'note': noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        'evidence_image_url': evidenceUrl,
        'latitude': widget.userLatitude,
        'longitude': widget.userLongitude,
      });

      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ContributionSuccessScreen()),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        submitting = false;
      });

      if (error.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already contributed to this report.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit contribution: ${error.message}'),
          ),
        );
      }
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios_new, color: navy),
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CIVICMIND',
                      style: TextStyle(
                        color: green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Incident Review',
                      style: TextStyle(
                        color: navy,
                        fontSize: 21,
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
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF344054),
                  size: 28,
                ),
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
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Incident Review & Verification',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.75,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFDCEFE9),
                  valueColor: const AlwaysStoppedAnimation<Color>(green),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExistingReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Similar Report',
                  style: TextStyle(
                    color: Color(0xFF176B9E),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                widget.distanceText,
                style: const TextStyle(
                  color: green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: widget.reportImageUrl.isNotEmpty
                    ? Image.network(
                        widget.reportImageUrl,
                        width: 115,
                        height: 105,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            width: 115,
                            height: 105,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                              size: 35,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 115,
                        height: 105,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 35,
                        ),
                      ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reportCategory,
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      widget.reportTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'An existing report appears to describe a similar civic issue near your location.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? const Color(0xFFD8E3FF) : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? orange : Colors.grey.shade600,
              size: 24,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              const Icon(Icons.check_circle, color: green, size: 23),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChoice({required String value, required String text}) {
    final selected = locationRelation == value;

    return InkWell(
      onTap: () {
        setState(() {
          locationRelation = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF087EBA) : const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, color: Colors.white, size: 17),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Add a note or photo as evidence',
              style: TextStyle(
                color: navy,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EDF8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        InkWell(
          onTap: _pickEvidencePhoto,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: evidenceBytes == null
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFF087EBA),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '+ Add Photo Evidence',
                        style: TextStyle(
                          color: Color(0xFF087EBA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          evidenceBytes!,
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Evidence photo selected',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            evidenceImage = null;
                            evidenceBytes = null;
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                "e.g. The pothole has worsened after yesterday's rain, traffic slowing down...",
            filled: true,
            fillColor: const Color(0xFFEFF4FF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: 18),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3E8DC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: orange,
                            size: 32,
                          ),
                        ),

                        const SizedBox(width: 15),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirm Your Contribution',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Provide verified details to attach your sighting as supporting evidence.',
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

                    const SizedBox(height: 20),

                    _buildExistingReportCard(),

                    const SizedBox(height: 25),

                    const Text(
                      "Is this the same problem you're seeing?",
                      style: TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildRadioOption(
                      selected: sameProblem,
                      title: 'Yes, it is the same problem',
                      subtitle:
                          'Your contribution helps verify and strengthen the existing report.',
                      onTap: () {
                        setState(() {
                          sameProblem = true;
                        });
                      },
                    ),

                    const SizedBox(height: 5),

                    _buildRadioOption(
                      selected: !sameProblem,
                      title: 'No, different issue',
                      subtitle:
                          'Return to create a separate report for this issue.',
                      onTap: () {
                        setState(() {
                          sameProblem = false;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        const Text(
                          'Where exactly did you notice it?',
                          style: TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Required',
                          style: TextStyle(
                            color: green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Help CivicMind understand whether it is the exact same spot or an expanded hazard.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 7,
                      runSpacing: 8,
                      children: [
                        _buildLocationChoice(
                          value: 'same_spot',
                          text: 'Same spot',
                        ),
                        _buildLocationChoice(
                          value: 'few_meters_away',
                          text: 'A few meters away',
                        ),
                        _buildLocationChoice(
                          value: 'same_stretch',
                          text: 'Along the same stretch',
                        ),
                      ],
                    ),

                    const SizedBox(height: 27),

                    _buildEvidenceSection(),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: submitting ? null : _submitContribution,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          disabledBackgroundColor: Colors.grey.shade400,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
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
                                    'Submit Contribution',
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

                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: green,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your contribution provides additional evidence for the existing civic issue report.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: submitting
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF475467),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
