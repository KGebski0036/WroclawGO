import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/attraction_models.dart';
import '../services/attraction_service.dart';
import '../state/app_session.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.session,
    required this.attractionService,
    super.key,
  });

  final AppSession session;
  final AttractionService attractionService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _wroclaw = LatLng(51.1079, 17.0385);
  static const _visitRangeMeters = 5000.0;

  MapLibreMapController? _mapController;

  List<Attraction> _attractions = const [];
  Set<int> _visitedAttractionIds = <int>{};
  Circle? _userCircle;
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  bool _markingVisited = false;

  bool _loading = true;
  String? _error;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAttractions());
    unawaited(_loadVisitedAttractions());
    unawaited(_startLocationTracking());
  }

  Future<void> _loadVisitedAttractions() async {
    final accessToken = widget.session.accessToken;
    if (accessToken == null) {
      return;
    }

    try {
      final visitedIds = await widget.attractionService
          .fetchVisitedAttractionIds(accessToken: accessToken);
      if (mounted) {
        setState(() {
          _visitedAttractionIds = visitedIds;
        });
      } else {
        _visitedAttractionIds = visitedIds;
      }
    } on ApiException catch (err) {
      if (err.statusCode == 401) {
        try {
          final refreshed = await widget.session.refreshAccessToken();
          final visitedIds = await widget.attractionService
              .fetchVisitedAttractionIds(accessToken: refreshed);
          if (mounted) {
            setState(() {
              _visitedAttractionIds = visitedIds;
            });
          } else {
            _visitedAttractionIds = visitedIds;
          }
        } catch (_) {
          await widget.session.clearSession();
        }
      }
    } catch (_) {
      // Do not block map when visited list fails to load.
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAttractions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attractions = await widget.attractionService.fetchAttractions();
      _attractions = attractions;
      if (_mapController != null) {
        await _drawAttractionCircles();
      }
    } catch (err) {
      setState(() {
        _error = 'Failed to load attractions: $err';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'Location service is disabled on this device.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _locationPermissionDenied = true;
      });
      return;
    }

    final current = await Geolocator.getCurrentPosition();
    _currentPosition = current;
    await _updateUserMarker(
      current.latitude,
      current.longitude,
      moveCamera: true,
    );

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
          ),
        ).listen((position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
          } else {
            _currentPosition = position;
          }
          unawaited(_updateUserMarker(position.latitude, position.longitude));
        });
  }

  Future<void> _updateUserMarker(
    double lat,
    double lng, {
    bool moveCamera = false,
  }) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    if (_userCircle != null) {
      await controller.removeCircle(_userCircle!);
    }

    _userCircle = await controller.addCircle(
      CircleOptions(
        geometry: LatLng(lat, lng),
        circleRadius: 8,
        circleColor: '#0F5D8C',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );

    if (moveCamera) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
      );
    }
  }

  Future<void> _drawAttractionCircles() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    for (final attraction in _attractions) {
      await controller.addCircle(
        CircleOptions(
          geometry: LatLng(attraction.latitude, attraction.longitude),
          circleRadius: 6,
          circleColor: Attraction.categoryHex(attraction.category),
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1.5,
        ),
      );
    }
  }

  Future<void> _centerOnUser() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      } else {
        _currentPosition = position;
      }
      await _updateUserMarker(
        position.latitude,
        position.longitude,
        moveCamera: true,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read current location.')),
        );
      }
    }
  }

  double? _distanceToAttraction(Attraction attraction) {
    final position = _currentPosition;
    if (position == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      attraction.latitude,
      attraction.longitude,
    );
  }

  Future<void> _markVisited(Attraction attraction) async {
    final distance = _distanceToAttraction(attraction);
    if (distance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location is unavailable.')),
      );
      return;
    }

    if (distance > _visitRangeMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are too far away. Current distance: ${_formatDistance(distance)} (limit: 5.0 km).',
          ),
        ),
      );
      return;
    }

    final accessToken = widget.session.accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be logged in to mark attractions as visited.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _markingVisited = true;
    });

    try {
      await widget.attractionService.markAsVisited(
        attractionId: attraction.id,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          _visitedAttractionIds = {..._visitedAttractionIds, attraction.id};
        });
      } else {
        _visitedAttractionIds = {..._visitedAttractionIds, attraction.id};
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked "${attraction.name}" as visited.')),
        );
      }
    } on ApiException catch (err) {
      if (err.statusCode == 401) {
        try {
          final refreshed = await widget.session.refreshAccessToken();
          await widget.attractionService.markAsVisited(
            attractionId: attraction.id,
            accessToken: refreshed,
          );

          if (mounted) {
            setState(() {
              _visitedAttractionIds = {..._visitedAttractionIds, attraction.id};
            });
          } else {
            _visitedAttractionIds = {..._visitedAttractionIds, attraction.id};
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Marked "${attraction.name}" as visited.'),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please log in again.'),
              ),
            );
          }
          await widget.session.clearSession();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err.message)));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark attraction as visited.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _markingVisited = false;
        });
      }
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Widget _buildAttractionActionsPanel() {
    final unvisited = _attractions
        .where((attraction) => !_visitedAttractionIds.contains(attraction.id))
        .toList();

    final sorted = [...unvisited]
      ..sort((a, b) {
        final da = _distanceToAttraction(a) ?? double.infinity;
        final db = _distanceToAttraction(b) ?? double.infinity;
        return da.compareTo(db);
      });

    final nearest = sorted.take(8).toList();

    if (nearest.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Nearby attractions (visit range: 5 km)'),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: nearest.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final attraction = nearest[index];
                  final distance = _distanceToAttraction(attraction);
                  final canMark =
                      distance != null &&
                      distance <= _visitRangeMeters &&
                      !_markingVisited;

                  return ListTile(
                    dense: true,
                    title: Text(
                      attraction.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      distance == null
                          ? 'Distance unavailable'
                          : '${_formatDistance(distance)} • ${attraction.category}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: canMark
                          ? () => _markVisited(attraction)
                          : null,
                      child: _markingVisited
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Visit'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WroclawGO Map'),
        actions: [
          IconButton(
            onPressed: _centerOnUser,
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
          ),
          IconButton(
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: 'https://tiles.openfreemap.org/styles/liberty',
            initialCameraPosition: const CameraPosition(
              target: _wroclaw,
              zoom: 13,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;
              await _drawAttractionCircles();
            },
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
          if (_locationPermissionDenied)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Location permission denied. Map still works without user position.',
                ),
              ),
            ),
          _buildAttractionActionsPanel(),
          if (_error != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                color: Colors.red.shade100,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
    );
  }
}
