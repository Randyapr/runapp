import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:runapp/data/running.dart';
import 'package:runapp/runningActivityService.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer();

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(-7.2200553310834, 107.9120193202365),
    zoom: 14,
  );

  List<LatLng> _polylineCoordinates = [];
  Set<Polyline> _polylines = {};
  Marker? _marker;
  StreamSubscription<Position>? _positionStream;
  double _totalKm = 0.0;
  double _totalCalories = 0.0;
  double _speed = 0.0;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  void _startTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        if (_polylineCoordinates.isNotEmpty) {
          final lastPosition = _polylineCoordinates.last;
          final km = Geolocator.distanceBetween(
            lastPosition.latitude,
            lastPosition.longitude,
            position.latitude,
            position.longitude,
          );
          _totalKm += km;

          final elapsedTime = _stopWatchTimer.rawTime.value /
              1000 /
              60 /
              60; // convert ka hours weh
          _speed = _totalKm / elapsedTime;
        }

        final newPosition = LatLng(position.latitude, position.longitude);
        _polylineCoordinates.add(newPosition);

        // Markerr
        _marker = Marker(
          markerId: MarkerId('current_position'),
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );

        // police line
        _polylines.add(Polyline(
          polylineId: PolylineId('Ruteu'),
          visible: true,
          points: _polylineCoordinates,
          width: 4,
          color: const Color.fromARGB(255, 4, 43, 75),
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: FloatingActionButton.extended(
                onPressed: _goToMyLocation,
                label: const Text(''),
                icon: const Icon(Icons.my_location),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildLariInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    Position position = await _determinePosition();
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14,
      ),
    ));
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Widget _buildLariInfo() {
    return Card(
      color: Colors.blue.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Km',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      (_totalKm / 1000).toStringAsFixed(2),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Speed',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _speed.toStringAsFixed(2),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Calories',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _totalCalories.toStringAsFixed(2),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    StreamBuilder<int>(
                      stream: _stopWatchTimer.rawTime,
                      initialData: 0,
                      builder: (context, snapshot) {
                        final value = snapshot.data!;
                        final displayTime =
                            StopWatchTimer.getDisplayTime(value);
                        return Text(
                          displayTime,
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _stopWatchTimer.onStartTimer,
                  child: Text('Start'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    _stopWatchTimer.onStopTimer();
                    final activity = RunningActivity(
                      date: DateTime.now(),
                      distance: _totalKm / 1000, // convertion m ka km
                      speed: _speed,
                      duration: _stopWatchTimer.rawTime.value,
                      calories: _totalCalories,
                    );
                    await RunningActivityService().saveActivity(activity);

                    Navigator.pop(context, activity);
                  },
                  child: Text('Stop & Save'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _stopWatchTimer.onResetTimer();
                  },
                  child: Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
