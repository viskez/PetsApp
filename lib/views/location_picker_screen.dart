import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

class LocationSelectionResult {
  const LocationSelectionResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.city,
    this.postalCode,
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? city;
  final String? postalCode;

  String get prettyLabel {
    final cityText = city?.isNotEmpty == true ? city : null;
    final pin = postalCode?.isNotEmpty == true ? postalCode : null;
    final values = <String>[
      formattedAddress,
      if (cityText != null) cityText,
      if (pin != null) 'PIN: $pin',
    ];
    return values.where((value) => value.trim().isNotEmpty).join(', ');
  }
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initialResult});

  final LocationSelectionResult? initialResult;

  static Route<LocationSelectionResult?> route({
    LocationSelectionResult? initialResult,
  }) {
    return MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerScreen(initialResult: initialResult),
    );
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const latlong.LatLng _defaultLatLng =
      latlong.LatLng(20.5937, 78.9629);
  final MapController _mapController = MapController();
  latlong.LatLng? _selectedLatLng;
  geocoding.Placemark? _placemark;
  bool _loadingInitial = true;
  bool _resolvingAddress = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final initial = widget.initialResult;
    if (initial != null) {
      _selectedLatLng = latlong.LatLng(initial.latitude, initial.longitude);
      _placemark = geocoding.Placemark(
        street: initial.formattedAddress,
        locality: initial.city,
        postalCode: initial.postalCode,
      );
      setState(() => _loadingInitial = false);
      return;
    }

    final hasPermission = await _ensureServiceAndPermission();
    if (!hasPermission) {
      setState(() => _loadingInitial = false);
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      _selectedLatLng = latlong.LatLng(current.latitude, current.longitude);
      setState(() => _loadingInitial = false);
      await _reverseGeocode(_selectedLatLng!);
    } catch (error) {
      setState(() {
        _loadingInitial = false;
        _statusMessage = 'Unable to fetch current location.';
      });
    }
  }

  Future<bool> _ensureServiceAndPermission() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      final turnOn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable GPS'),
          content: const Text(
            'Location services are turned off. Please enable GPS to pick a location on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (!mounted) return false;
      if (turnOn == true) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'GPS is off. Turn it on to continue.';
        });
        return false;
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Location permission is required to pick a point.';
      });
      return false;
    }
    return true;
  }

  Future<void> _reverseGeocode(latlong.LatLng target) async {
    setState(() {
      _resolvingAddress = true;
      _statusMessage = null;
    });
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );
      setState(() {
        _placemark = placemarks.isNotEmpty ? placemarks.first : null;
        _resolvingAddress = false;
      });
    } catch (error) {
      setState(() {
        _resolvingAddress = false;
        _statusMessage = 'Could not fetch address for this point.';
      });
    }
  }

  void _onMapTapped(latlong.LatLng latLng) {
    setState(() => _selectedLatLng = latLng);
    _mapController.move(latLng, _mapController.camera.zoom);
    unawaited(_reverseGeocode(latLng));
  }

  Future<void> _centerOnCurrentLocation() async {
    final hasPermission = await _ensureServiceAndPermission();
    if (!hasPermission) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      final latLng = latlong.LatLng(position.latitude, position.longitude);
      setState(() => _selectedLatLng = latLng);
      _mapController.move(latLng, 16);
      await _reverseGeocode(latLng);
    } catch (error) {
      setState(() {
        _statusMessage = 'Unable to read GPS position.';
      });
    }
  }

  String get _addressDisplay {
    if (_placemark == null) {
      return 'Tap on the map to place a pin.';
    }
    final parts = <String>[];
    void addPart(String? value) {
      if (value != null && value.trim().isNotEmpty) {
        parts.add(value.trim());
      }
    }

    addPart(_placemark?.street);
    addPart(_placemark?.subLocality);
    addPart(_placemark?.locality);
    addPart(_placemark?.administrativeArea);
    addPart(_placemark?.postalCode);
    return parts.isEmpty ? 'Address unavailable' : parts.join(', ');
  }

  Future<void> _openInGoogleMaps() async {
    final target = _selectedLatLng;
    final uri = target == null
        ? Uri.parse('https://www.google.com/maps')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}',
          );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _submit() {
    final target = _selectedLatLng;
    if (target == null) {
      setState(() {
        _statusMessage = 'Please tap on the map to choose a location.';
      });
      return;
    }
    final result = LocationSelectionResult(
      latitude: target.latitude,
      longitude: target.longitude,
      formattedAddress: _addressDisplay,
      city: _placemark?.locality ?? _placemark?.subAdministrativeArea,
      postalCode: _placemark?.postalCode,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final cameraTarget = _selectedLatLng ?? _defaultLatLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
        actions: [
          IconButton(
            tooltip: 'Open in Google Maps',
            onPressed: _openInGoogleMaps,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fabMyLocation',
        onPressed: _centerOnCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
      body: _loadingInitial
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: cameraTarget,
                      initialZoom: _selectedLatLng == null ? 5 : 16,
                      onTap: (tapPosition, latLng) => _onMapTapped(latLng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.petsapp',
                      ),
                      if (_selectedLatLng != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLatLng!,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                size: 40,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _addressDisplay,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_selectedLatLng != null)
                                  Text(
                                    'Lat: ${_selectedLatLng!.latitude.toStringAsFixed(5)}, '
                                    'Lng: ${_selectedLatLng!.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (_statusMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _statusMessage!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_resolvingAddress) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Use this location'),
                          onPressed: _selectedLatLng == null || _resolvingAddress
                              ? null
                              : _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
