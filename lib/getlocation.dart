import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class GetLocation extends StatefulWidget {
  const GetLocation({super.key});

  @override
  _GetLocationState createState() => _GetLocationState();
}

class _GetLocationState extends State<GetLocation> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(19.0760, 72.8777); // Mumbai coordinates
  LatLng _lastMapPosition = const LatLng(19.0760, 72.8777); // Mumbai coordinates
  String _address = ""; // Variable to store address
  Set<Marker> _markers = {}; // Set of markers for Google Maps
  bool _isLoading = false; // Loading indicator state

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else if (status.isDenied) {
      print("Location permission denied");
    } else if (status.isPermanentlyDenied) {
      print("Location permission permanently denied");
      openAppSettings();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _updateMarkerPosition(LatLng(position.latitude, position.longitude));
      mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (e) {
      print("Error getting location: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  void _onCameraMove(CameraPosition position) {
    _lastMapPosition = position.target;
  }

  void _onCameraIdle() async {
    if (!_isLoading) {
      await _updateMarkerPosition(_lastMapPosition);
    }
  }

  Future<void> _updateMarkerPosition(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        String thoroughfare = placemark.thoroughfare ?? "";
        String subThoroughfare = placemark.subThoroughfare ?? "";
        String locality = placemark.locality ?? "";
        String administrativeArea = placemark.administrativeArea ?? "";
        String postalCode = placemark.postalCode ?? "";
        String country = placemark.country ?? "";

        String address = '$thoroughfare $subThoroughfare, $locality, $administrativeArea $postalCode, $country';

        setState(() {
          _address = address;
          _markers = {
            Marker(
              markerId: MarkerId(position.toString()),
              position: position,
              draggable: true,
              infoWindow: InfoWindow(
                title: 'Selected Location',
                snippet: _address,
              ),
              onTap: () {
                _onMarkerTapped(position);
              },
              onDragEnd: _onMarkerDragEnd,
            ),
          };
        });
      }
    } catch (e) {
      print("Error updating marker: $e");
    }
  }

  void _onMarkerDragEnd(LatLng position) async {
    await _updateMarkerPosition(position);
  }

  void _onMarkerTapped(LatLng position) async {
    await _updateMarkerPosition(position);
  }

  void _saveLocation() {
    Navigator.pop(context, {
      'position': _lastMapPosition,
      'selectedAddress': _address,
    });
  }

  void _goToCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      mapController.animateCamera(
        CameraUpdate.newLatLng(currentLatLng),
      );

      await _updateMarkerPosition(currentLatLng);
    } catch (e) {
      print("Error getting current location: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.yellow,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
            markers: _markers,
            onTap: (LatLng position) {
              _onMarkerDragEnd(position);
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.yellow,
              ),
            ),
        ],
     ),
);
}
}