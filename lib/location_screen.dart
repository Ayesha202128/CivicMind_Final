import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';

import 'report_issue_screen.dart';

class LocationScreen extends StatefulWidget {
  final XFile selectedImage;

  const LocationScreen({super.key, required this.selectedImage});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  final MapController _mapController = MapController();

  Position? currentPosition;

  bool loading = false;
  String? errorMessage;

  Future<void> _getCurrentLocation() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // 1. Check GPS/location service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          loading = false;
          errorMessage =
              'Location service is disabled. Please turn on GPS/Location.';
        });
        return;
      }

      // 2. Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. Request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Permission denied
      if (permission == LocationPermission.denied) {
        setState(() {
          loading = false;
          errorMessage = 'Location permission was denied.';
        });
        return;
      }

      // 5. Permission permanently denied
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          loading = false;
          errorMessage =
              'Location permission is permanently denied. Please enable it from settings.';
        });
        return;
      }

      // 6. Get current GPS location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        loading = false;
        errorMessage = null;
      });

      // 7. Move map to current location
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } catch (e) {
      debugPrint('LOCATION ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Could not get your location. Please try again.';
      });
    }
  }

  void _useThisLocation() {
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please get your current location first.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportIssueScreen(
          selectedImage: widget.selectedImage,
          latitude: currentPosition!.latitude,
          longitude: currentPosition!.longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = currentPosition == null
        ? const LatLng(23.8103, 90.4125)
        : LatLng(currentPosition!.latitude, currentPosition!.longitude);

    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          'Location',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where did this happen?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Get your current location and confirm it on the map.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),

              const SizedBox(height: 16),

              // MAP
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.civicmind',
                          ),

                          if (currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    currentPosition!.latitude,
                                    currentPosition!.longitude,
                                  ),
                                  width: 55,
                                  height: 55,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: orange,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 8,
                                          color: Colors.black26,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // Current location floating button
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          foregroundColor: navy,
                          onPressed: currentPosition == null
                              ? _getCurrentLocation
                              : () {
                                  _mapController.move(
                                    LatLng(
                                      currentPosition!.latitude,
                                      currentPosition!.longitude,
                                    ),
                                    16,
                                  );
                                },
                          child: const Icon(Icons.my_location),
                        ),
                      ),

                      // Loading overlay
                      if (loading)
                        Container(
                          color: Colors.white70,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: orange),
                                SizedBox(height: 12),
                                Text(
                                  'Finding your location...',
                                  style: TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ERROR
              if (errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),

              const SizedBox(height: 12),

              // Coordinates
              if (currentPosition != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${currentPosition!.latitude.toStringAsFixed(6)}, '
                          '${currentPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '±${currentPosition!.accuracy.toStringAsFixed(0)}m',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Get location / update
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location, color: navy),
                  label: Text(
                    currentPosition == null
                        ? 'Get Current Location'
                        : 'Update Location',
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // NEXT
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: currentPosition == null || loading
                      ? null
                      : _useThisLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Use This Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
