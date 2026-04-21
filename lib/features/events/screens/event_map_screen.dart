import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../services/mock_event_service.dart';
import '../models/event_model.dart';
import 'event_detail_screen.dart';

class EventMapScreen extends StatefulWidget {
  const EventMapScreen({super.key});

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum servisleri kapalı.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni reddedildi.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  EventModel? _selectedEvent;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _loadEventMarkers();
  }

  void _loadEventMarkers() {
    final eventService = context.read<MockEventService>();
    final events = eventService.allEvents.where((e) => e.latitude != null && e.longitude != null);

    final markers = events.map((event) {
      return Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude!, event.longitude!),
        onTap: () {
          setState(() {
            _selectedEvent = event;
          });
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(event.latitude!, event.longitude!),
              ),
            );
          }
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerHue(event.category),
        ),
      );
    }).toSet();

    setState(() {
      _markers = markers;
    });
  }

  double _getMarkerHue(String category) {
    switch (category.toLowerCase()) {
      case 'tiyatro':
        return BitmapDescriptor.hueOrange;
      case 'konser':
        return BitmapDescriptor.hueViolet;
      case 'stand-up':
        return BitmapDescriptor.hueYellow;
      case 'festival':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Haritası'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : LatLng(41.0082, 28.9784), // Default to Istanbul
                    zoom: 12,
                  ),
                  onTap: (_) {
                    setState(() {
                      _selectedEvent = null;
                    });
                  },
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: _mapStyle,
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  bottom: _selectedEvent != null ? 32 : -200,
                  left: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _selectedEvent != null ? 1.0 : 0.0,
                    child: _selectedEvent != null ? _buildEventPreview(_selectedEvent!) : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventPreview(EventModel event) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              // Event Image with Badge
              Stack(
                children: [
                  SizedBox(
                    width: 130,
                    height: double.infinity,
                    child: Hero(
                      tag: 'event_image_${event.id}',
                      child: event.imageUrl.startsWith('http')
                          ? Image.network(event.imageUrl, fit: BoxFit.cover)
                          : Image.asset(event.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  if (event.isPopular)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Text(
                          'POPÜLER',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              // Event Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.flash_on, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            event.atmosphere,
                            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniBadge(event.category, AppColors.primary),
                          const SizedBox(width: 8),
                          _buildDirectionButton(event),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Go Button
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(event: event),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: double.infinity,
                  color: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.chevron_right, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDirectionButton(EventModel event) {
    return InkWell(
      onTap: () async {
        final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: const Icon(Icons.directions, color: Colors.blue, size: 16),
      ),
    );
  }

  // Premium dark style for the map
  final String _mapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9e9e9e"}]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#bdbdbd"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#181818"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#1b1b1b"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#2c2c2c"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8a8a8a"}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [{"color": "#373737"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#3c3c3c"}]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [{"color": "#4e4e4e"}]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#616161"}]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#3d3d3d"}]
  }
]
''';
}
