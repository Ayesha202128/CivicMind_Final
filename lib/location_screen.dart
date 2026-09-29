import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

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
  final Geocoding _geocoding = Geocoding();

  final TextEditingController _searchController = TextEditingController();

  Timer? _addressTimer;

  // ----------------------------------------------------------
  // SELECTED LOCATION
  // ----------------------------------------------------------

  LatLng selectedLocation = const LatLng(23.8103, 90.4125);

  Position? currentPosition;

  // ----------------------------------------------------------
  // LOCATION INFORMATION
  // ----------------------------------------------------------

  String selectedAddress = 'Dhaka, Bangladesh';

  String? errorMessage;

  bool loading = false;
  bool mapReady = false;
  bool searching = false;

  // ----------------------------------------------------------
  // MAP READY
  // ----------------------------------------------------------

  void _onMapReady() {
    mapReady = true;
  }

  // ----------------------------------------------------------
  // MAP MOVED
  // ----------------------------------------------------------

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!mounted) return;

    final center = camera.center;

    setState(() {
      selectedLocation = center;
    });

    // Don't reverse-geocode every single map movement.
    // Wait until the user stops moving the map.
    _addressTimer?.cancel();

    _addressTimer = Timer(const Duration(milliseconds: 700), () {
      _getAddressFromCoordinates(center.latitude, center.longitude);
    });
  }

  // ----------------------------------------------------------
  // REVERSE GEOCODING
  // COORDINATES -> ADDRESS
  // ----------------------------------------------------------

  Future<void> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty || !mounted) return;

      final place = placemarks.first;

      final parts = <String>[];

      if (place.street != null && place.street!.trim().isNotEmpty) {
        parts.add(place.street!.trim());
      }

      if (place.subLocality != null && place.subLocality!.trim().isNotEmpty) {
        parts.add(place.subLocality!.trim());
      }

      if (place.locality != null && place.locality!.trim().isNotEmpty) {
        parts.add(place.locality!.trim());
      }

      if (place.administrativeArea != null &&
          place.administrativeArea!.trim().isNotEmpty &&
          !parts.contains(place.administrativeArea!.trim())) {
        parts.add(place.administrativeArea!.trim());
      }

      if (place.country != null &&
          place.country!.trim().isNotEmpty &&
          !parts.contains(place.country!.trim())) {
        parts.add(place.country!.trim());
      }

      if (!mounted) return;

      setState(() {
        if (parts.isNotEmpty) {
          selectedAddress = parts.join(', ');
        } else {
          selectedAddress = 'Address not available for this location';
        }
      });
    } catch (e) {
      debugPrint('REVERSE GEOCODING ERROR: $e');
    }
  }

  // ----------------------------------------------------------
  // SEARCH ADDRESS
  // ADDRESS -> COORDINATES
  // ----------------------------------------------------------

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      searching = true;
      errorMessage = null;
    });

    try {
      final locations = await _geocoding.locationFromAddress(query);

      if (locations.isEmpty) {
        throw Exception(
          'Location not found. Try a road, area, city or address.',
        );
      }

      final location = locations.first;

      final newPoint = LatLng(location.latitude, location.longitude);

      if (!mounted) return;

      setState(() {
        selectedLocation = newPoint;
        selectedAddress = query;
        searching = false;
        errorMessage = null;
      });

      if (mapReady) {
        _mapController.move(newPoint, 17);
      }

      // Get the actual address after moving.
      await _getAddressFromCoordinates(location.latitude, location.longitude);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        searching = false;
        errorMessage =
            'Location not found. Try something like '
            '"Sagardighi Road, Sylhet".';
      });
    }
  }

  // ----------------------------------------------------------
  // GET CURRENT GPS LOCATION
  // ----------------------------------------------------------

  Future<void> _getCurrentLocation() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Please turn on GPS / Location service.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Enable it from app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final gpsPoint = LatLng(position.latitude, position.longitude);

      setState(() {
        currentPosition = position;
        selectedLocation = gpsPoint;
        loading = false;
        errorMessage = null;
        selectedAddress = 'Finding current address...';
      });

      if (mapReady) {
        _mapController.move(gpsPoint, 18);
      }

      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ----------------------------------------------------------
  // GO TO CURRENT LOCATION
  // ----------------------------------------------------------

  void _goToMyLocation() {
    if (currentPosition == null) {
      _getCurrentLocation();
      return;
    }

    final point = LatLng(currentPosition!.latitude, currentPosition!.longitude);

    setState(() {
      selectedLocation = point;
      selectedAddress = 'Finding current address...';
    });

    _mapController.move(point, 18);

    _getAddressFromCoordinates(point.latitude, point.longitude);
  }

  // ----------------------------------------------------------
  // GOOGLE DIRECTIONS
  // ----------------------------------------------------------

  Future<void> _openDirections() async {
    final lat = selectedLocation.latitude;
    final lng = selectedLocation.longitude;

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng'
      '&travelmode=walking',
    );

    await _openExternalMap(url);
  }

  // ----------------------------------------------------------
  // GOOGLE STREET VIEW
  // ----------------------------------------------------------

  Future<void> _openStreetView() async {
    final lat = selectedLocation.latitude;
    final lng = selectedLocation.longitude;

    final url = Uri.parse(
      'https://www.google.com/maps/@?api=1'
      '&map_action=pano'
      '&viewpoint=$lat,$lng',
    );

    await _openExternalMap(url);
  }

  // ----------------------------------------------------------
  // OPEN EXTERNAL MAP
  // ----------------------------------------------------------

  Future<void> _openExternalMap(Uri url) async {
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
    }
  }

  // ----------------------------------------------------------
  // CONFIRM LOCATION
  // ----------------------------------------------------------

  void _useThisLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportIssueScreen(
          selectedImage: widget.selectedImage,
          latitude: selectedLocation.latitude,
          longitude: selectedLocation.longitude,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // BACK
  // ----------------------------------------------------------

  void _goBack() {
    Navigator.pop(context);
  }

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    _addressTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      // ======================================================
      // APP BAR
      // ======================================================
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          'Confiem Location',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // TITLE
              // ==================================================
              const Text(
                'Where did this happen?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Find the location or move the map '
                'to select the exact problem area.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // SEARCH BAR
              // ==================================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchLocation(),
                  decoration: InputDecoration(
                    hintText: 'Search road, area or address',
                    prefixIcon: const Icon(Icons.search, color: navy),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: orange,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _searchLocation,
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: orange,
                            ),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // MAP
              // ==================================================
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,

                        options: MapOptions(
                          initialCenter: selectedLocation,

                          initialZoom: 13,

                          onMapReady: _onMapReady,

                          onPositionChanged: _onPositionChanged,

                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),

                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/'
                                '{z}/{x}/{y}.png',

                            userAgentPackageName: 'com.example.civicmind',
                          ),
                        ],
                      ),

                      // ==================================================
                      // FIXED CENTER PIN
                      // ==================================================
                      const IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 34),
                            child: Icon(
                              Icons.location_on,
                              size: 50,
                              color: orange,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // CENTER DOT
                      // ==================================================
                      const IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Icon(Icons.circle, size: 7, color: navy),
                          ),
                        ),
                      ),

                      // ==================================================
                      // MY LOCATION BUTTON
                      // ==================================================
                      Positioned(
                        right: 12,
                        bottom: 16,
                        child: FloatingActionButton(
                          heroTag: 'myLocationButton',

                          mini: true,

                          backgroundColor: Colors.white,

                          foregroundColor: navy,

                          onPressed: loading ? null : _goToMyLocation,

                          child: const Icon(Icons.my_location),
                        ),
                      ),

                      // ==================================================
                      // OSM ATTRIBUTION
                      // ==================================================
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),

                      // ==================================================
                      // LOADING
                      // ==================================================
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
                                    fontWeight: FontWeight.w600,
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

              const SizedBox(height: 10),

              // ==================================================
              // ERROR
              // ==================================================
              if (errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),

              // ==================================================
              // ADDRESS CARD
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: orange),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected problem location',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            selectedAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            '${selectedLocation.latitude.toStringAsFixed(6)}, '
                            '${selectedLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // DIRECTIONS + STREET VIEW
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _openDirections,

                      icon: const Icon(Icons.directions, size: 19),

                      label: const Text('Directions'),

                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,

                        side: const BorderSide(color: navy),

                        padding: const EdgeInsets.symmetric(vertical: 10),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _openStreetView,

                      icon: const Icon(Icons.streetview, size: 19),

                      label: const Text('Street View'),

                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,

                        side: const BorderSide(color: navy),

                        padding: const EdgeInsets.symmetric(vertical: 10),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ==================================================
              // CURRENT LOCATION + CONFIRM
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _getCurrentLocation,

                      icon: const Icon(Icons.gps_fixed),

                      label: const Text(
                        'My Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,

                        side: const BorderSide(color: navy),

                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _useThisLocation,

                      icon: const Icon(Icons.check_circle, color: Colors.white),

                      label: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,

                        disabledBackgroundColor: Colors.grey.shade300,

                        padding: const EdgeInsets.symmetric(vertical: 14),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
