import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  Position? position;
  bool loading = false;
  String? errorMessage;

  Future<void> _getCurrentLocation() async {
    setState(() {
      loading = true;
      errorMessage = null;
      position = null;
    });

    try {
      // 1. Check whether location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          loading = false;
          errorMessage =
              'Location service is disabled. Please turn on GPS/Location.';
        });
        return;
      }

      // 2. Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      // 3. Ask for permission if needed
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 4. User denied permission
      if (permission == LocationPermission.denied) {
        setState(() {
          loading = false;
          errorMessage = 'Location permission was denied.';
        });
        return;
      }

      // 5. User permanently denied permission
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          loading = false;
          errorMessage =
              'Location permission is permanently denied. Please enable it from settings.';
        });
        return;
      }

      // 6. Get current location
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        position = currentPosition;
        loading = false;
      });
    } catch (e) {
      debugPrint('LOCATION ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Could not get your location. Please try again.';
      });
    }
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
          'Location Test',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Current Location',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: navy,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'We will use your location to identify where the civic issue was reported.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _buildLocationContent(),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: loading ? null : _getCurrentLocation,
                icon: const Icon(Icons.my_location, color: Colors.white),
                label: Text(
                  loading ? 'Getting Location...' : 'Get My Location',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationContent() {
    if (loading) {
      return const Column(
        children: [
          CircularProgressIndicator(color: orange),
          SizedBox(height: 16),
          Text(
            'Finding your location...',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      );
    }

    if (errorMessage != null) {
      return Column(
        children: [
          const Icon(Icons.location_off_outlined, size: 50, color: orange),
          const SizedBox(height: 14),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      );
    }

    if (position == null) {
      return const Column(
        children: [
          Icon(Icons.location_on_outlined, size: 50, color: navy),
          SizedBox(height: 14),
          Text(
            'Location not detected yet.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      );
    }

    return Column(
      children: [
        const Icon(Icons.location_on, size: 50, color: orange),

        const SizedBox(height: 16),

        const Text(
          'Location detected successfully!',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),

        const SizedBox(height: 20),

        _locationRow('Latitude', position!.latitude.toStringAsFixed(6)),

        const SizedBox(height: 12),

        _locationRow('Longitude', position!.longitude.toStringAsFixed(6)),

        const SizedBox(height: 12),

        _locationRow(
          'Accuracy',
          '${position!.accuracy.toStringAsFixed(1)} meters',
        ),
      ],
    );
  }

  Widget _locationRow(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
