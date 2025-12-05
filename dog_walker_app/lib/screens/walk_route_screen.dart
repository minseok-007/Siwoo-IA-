import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/walk_route_service.dart';

/// Screen that displays Google Maps with the user's current location.
/// 
/// Features:
/// - Shows Google Maps centered on user's current location
/// - Requests location permissions if not granted
/// - Displays current location marker
/// - Provides location button to recenter map
class WalkRouteScreen extends StatefulWidget {
  const WalkRouteScreen({super.key});

  @override
  State<WalkRouteScreen> createState() => _WalkRouteScreenState();
}

class _WalkRouteScreenState extends State<WalkRouteScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _errorMessage;
  
  // Default location (Seoul City Hall) - zoomed in
  static const LatLng _defaultLocation = LatLng(37.5665, 126.9780);
  
  // Route recommendation state
  final WalkRouteService _routeService = WalkRouteService();
  List<WalkRoute> _recommendedRoutes = [];
  WalkRoute? _selectedRoute;
  bool _isGeneratingRoutes = false;
  Set<Polyline> _polylines = {};
  Set<Marker> _routeMarkers = {};
  WalkPreferences _preferences = WalkPreferences.balanced();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Set default to Seoul with zoom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnSeoul();
    });
  }
  
  /// Centers map on Seoul with zoom
  void _centerOnSeoul() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_defaultLocation, 14.0),
      );
    }
  }

  /// Requests location permission and gets the current location
  Future<void> _getCurrentLocation({bool showError = false}) async {
    try {
      setState(() {
        _isLoadingLocation = true;
        if (!showError) {
          _errorMessage = null; // Don't show error unless explicitly requested
        }
      });

      // First, try to get last known position (works in simulators without permission)
      Position? position = await _tryLastKnownPosition();
      
      // If we got a position, use it
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _errorMessage = null;
        });
        
        // Move camera to position
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15.0,
            ),
          );
        }
        return;
      }

      // If no last known position, check permission status (don't request yet)
      final status = await Permission.location.status;
      
      // Only request if not permanently denied
      if (status.isDenied) {
        final requestResult = await Permission.location.request();
        if (!requestResult.isGranted) {
          // Still try last known position after request
          position = await _tryLastKnownPosition();
        }
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try last known position even if service is disabled
        position = await _tryLastKnownPosition();
        if (position != null) {
          setState(() {
            _currentPosition = position;
            _isLoadingLocation = false;
            _errorMessage = null;
          });
          return;
        }
        if (showError) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = 'Location services are disabled.';
          });
        } else {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      // Try to get current position if we have permission
      final currentStatus = await Permission.location.status;
      if (currentStatus.isGranted) {
        try {
          // Try high accuracy first (GPS)
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
        } catch (e) {
          // If GPS fails, try lower accuracy (network-based, works better in simulators)
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low, // Network-based location
              ),
            );
          } catch (e2) {
            // If that also fails, try last known position
            position = await _tryLastKnownPosition();
          }
        }
      } else {
        // Permission denied - try last known position (works in simulators)
        position = await _tryLastKnownPosition();
      }

      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _errorMessage = null;
        });

        // Move camera to current location
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15.0,
            ),
          );
        }
      } else {
        // No position available - silently fail (don't show error unless requested)
        setState(() {
          _isLoadingLocation = false;
          if (showError) {
            _errorMessage = 'Unable to get location.';
          } else {
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        if (showError) {
          _errorMessage = 'Failed to get location.';
        } else {
          _errorMessage = null;
        }
      });
    }
  }

  /// Try to get last known position (works in simulators even without permission)
  Future<Position?> _tryLastKnownPosition() async {
    try {
      // Check permission first
      final status = await Permission.location.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        return null;
      }
      
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && _mapController != null) {
        // Move camera to last known position
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(lastPosition.latitude, lastPosition.longitude),
            15.0,
          ),
        );
      }
      return lastPosition;
    } catch (e) {
      // Silently fail - permission might not be granted
      return null;
    }
  }

  /// Recenters the map to the current location
  Future<void> _recenterToCurrentLocation() async {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Walk Route',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map - Always show, even without location permission
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : _defaultLocation,
              zoom: _currentPosition != null ? 15.0 : 14.0, // Zoomed in for Seoul
            ),
            onMapCreated: (GoogleMapController controller) async {
              _mapController = controller;
              // If we have current position, move camera to it
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    15.0,
                  ),
                );
              } else {
                // Center on Seoul by default
                _centerOnSeoul();
                // If no position yet, try to get last known position
                // This helps in simulators where permission might be pending
                try {
                  final lastPosition = await Geolocator.getLastKnownPosition();
                  if (lastPosition != null) {
                    setState(() {
                      _currentPosition = lastPosition;
                    });
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(lastPosition.latitude, lastPosition.longitude),
                        15.0,
                      ),
                    );
                  }
                } catch (e) {
                  // Silently fail - permission might not be granted yet
                  // Will try again when user grants permission
                }
              }
            },
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: false, // We'll add custom button
            markers: _buildMarkers(),
            polylines: _polylines,
          ),

          // Loading overlay
          if (_isLoadingLocation)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error message removed - app works silently without location permission

          // Route recommendation panel
          if (_recommendedRoutes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRouteRecommendationPanel(),
            ),

          // Generate routes button
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: _generateRecommendedRoutes,
                  backgroundColor: Colors.green[600],
                  heroTag: "generate_routes",
                  child: _isGeneratingRoutes
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.route, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: _showPreferencesDialog,
                  backgroundColor: Colors.orange[600],
                  heroTag: "preferences",
                  child: const Icon(Icons.tune, color: Colors.white),
                ),
              ],
            ),
          ),

          // Floating action button to recenter or get location
          Positioned(
            bottom: _recommendedRoutes.isNotEmpty ? 200 : 24,
            right: 16,
            child: FloatingActionButton(
              onPressed: _currentPosition != null
                  ? _recenterToCurrentLocation
                  : () => _getCurrentLocation(showError: false),
              backgroundColor: Colors.blue[600],
              heroTag: "location",
              child: Icon(
                _currentPosition != null ? Icons.my_location : Icons.location_searching,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds markers for the map
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    
    // Current location marker
    final currentLocation = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultLocation;
    
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Current Location',
        ),
      ),
    );
    
    // Route waypoint markers
    markers.addAll(_routeMarkers);
    
    return markers;
  }

  /// Generates recommended walking routes
  Future<void> _generateRecommendedRoutes() async {
    setState(() {
      _isGeneratingRoutes = true;
      _recommendedRoutes = [];
      _selectedRoute = null;
      _polylines.clear();
      _routeMarkers.clear();
    });

    try {
      final startLocation = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : _defaultLocation;

      final routes = await _routeService.generateRecommendedRoutes(
        startLocation: startLocation,
        targetDistance: 2000.0, // 2km default
        preferences: _preferences,
      );

      setState(() {
        _recommendedRoutes = routes;
        _isGeneratingRoutes = false;
      });

      if (routes.isNotEmpty) {
        _selectRoute(routes.first);
      }
    } catch (e) {
      setState(() {
        _isGeneratingRoutes = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating routes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Selects a route and displays it on the map
  void _selectRoute(WalkRoute route) {
    setState(() {
      _selectedRoute = route;
      _polylines.clear();
      _routeMarkers.clear();
      
      // Create polyline for the route
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('recommended_route'),
          points: route.path,
          color: Colors.green,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
      
      // Add markers for waypoints
      for (int i = 0; i < route.waypoints.length; i++) {
        _routeMarkers.add(
          Marker(
            markerId: MarkerId('waypoint_$i'),
            position: route.waypoints[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == 0 
                  ? BitmapDescriptor.hueGreen 
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: i == 0 ? 'Start' : 'Waypoint ${i + 1}',
            ),
          ),
        );
      }
    });

    // Animate camera to show the route
    if (_mapController != null && route.path.isNotEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          _calculateBounds(route.path),
          100.0,
        ),
      );
    }
  }

  /// Calculates bounds for a list of points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLon = minLon < point.longitude ? minLon : point.longitude;
      maxLon = maxLon > point.longitude ? maxLon : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Builds the route recommendation panel
  Widget _buildRouteRecommendationPanel() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Recommended Routes',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _recommendedRoutes = [];
                      _selectedRoute = null;
                      _polylines.clear();
                      _routeMarkers.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recommendedRoutes.length,
              itemBuilder: (context, index) {
                final route = _recommendedRoutes[index];
                final isSelected = _selectedRoute == route;
                return GestureDetector(
                  onTap: () => _selectRoute(route),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.route,
                              color: isSelected ? Colors.green : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Route ${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.green : Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                route.distanceDisplay,
                                style: GoogleFonts.poppins(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Score: ${route.scoreDisplay}',
                                style: GoogleFonts.poppins(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Shows preferences dialog
  void _showPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Route Preferences', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Balanced'),
              leading: Radio<WalkPreferences>(
                value: WalkPreferences.balanced(),
                groupValue: _preferences,
                onChanged: (value) {
                  setState(() => _preferences = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Nature Focused'),
              leading: Radio<WalkPreferences>(
                value: WalkPreferences.natureFocused(),
                groupValue: _preferences,
                onChanged: (value) {
                  setState(() => _preferences = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Urban Walk'),
              leading: Radio<WalkPreferences>(
                value: WalkPreferences.urban(),
                groupValue: _preferences,
                onChanged: (value) {
                  setState(() => _preferences = value!);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

