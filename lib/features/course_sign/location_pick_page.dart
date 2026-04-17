import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';

import '../../core/location/baidu_location_service.dart';
import 'university_location_search.dart';

class LocationPickResult {
  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  final double latitude;
  final double longitude;
  final String locationName;
}

class LocationPickPage extends StatefulWidget {
  const LocationPickPage({super.key});

  @override
  State<LocationPickPage> createState() => _LocationPickPageState();
}

class _LocationPickPageState extends State<LocationPickPage> {
  static const _defaultLat = 30.2741;
  static const _defaultLon = 120.1551;
  static const _maxSearchResultCount = 30;

  final TextEditingController _searchController = TextEditingController();
  final UniversityLocationSearch _universitySearch = UniversityLocationSearch();
  Timer? _searchDebounce;

  BMFMapController? _mapController;
  double _centerLat = _defaultLat;
  double _centerLon = _defaultLon;
  double? _selectedLat;
  double? _selectedLon;
  String _selectedName = '';

  bool _loadingLocation = false;
  bool _searching = false;
  bool _mapReady = false;
  String? _selectedDotId;
  List<_PoiItem> _searchResults = const [];
  ({double lat, double lon})? _pendingCenter;

  @override
  void initState() {
    super.initState();
    _locateAndMove();
    _warmupLocalSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateAndMove() async {
    setState(() {
      _loadingLocation = true;
    });
    try {
      final point = await BaiduLocationService.instance
          .locateOnce(timeout: const Duration(seconds: 12))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _centerLat = point.latitude;
        _centerLon = point.longitude;
        _selectedLat ??= point.latitude;
        _selectedLon ??= point.longitude;
      });
      await _refreshSelectDot();
      await _moveTo(point.latitude, point.longitude, zoom: 18);
    } catch (_) {
      // keep default center
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _searchPlaces({String? keyword, bool silent = false}) async {
    final kw = (keyword ?? _searchController.text).trim();
    if (kw.isEmpty) return;
    setState(() {
      _searching = true;
    });
    try {
      await _universitySearch.ensureLoaded();
      final locations = _universitySearch.search(
        kw,
        limit: _maxSearchResultCount,
      );
      final results = <_PoiItem>[
        for (final item in locations)
          _PoiItem(
            name: item.name,
            address: item.fullAddress,
            latitude: item.latitude,
            longitude: item.longitude,
          ),
      ];
      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
      if (results.isNotEmpty) {
        final first = results.first;
        await _moveTo(first.latitude, first.longitude, zoom: 18);
      } else if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未匹配到地点，请换关键词')));
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地点库加载失败')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _warmupLocalSearch() async {
    try {
      await _universitySearch.ensureLoaded();
    } catch (_) {
      // ignore
    }
  }

  void _onSearchInputChanged(String value) {
    _searchDebounce?.cancel();
    final kw = value.trim();
    if (kw.isEmpty) {
      setState(() {
        _searchResults = const [];
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      _searchPlaces(keyword: kw, silent: true);
    });
  }

  Future<void> _moveTo(double lat, double lon, {double zoom = 17}) async {
    final c = _mapController;
    if (!_mapReady || c == null) {
      _pendingCenter = (lat: lat, lon: lon);
      return;
    }
    await c.setNewLatLngZoom(
      coordinate: BMFCoordinate(lat, lon),
      zoom: zoom,
      animateDurationMs: 300,
    );
  }

  Future<void> _refreshSelectDot() async {
    final c = _mapController;
    final lat = _selectedLat;
    final lon = _selectedLon;
    if (!_mapReady || c == null || lat == null || lon == null) return;
    final oldId = _selectedDotId;
    if (oldId != null && oldId.isNotEmpty) {
      await c.removeOverlay(oldId);
    }
    final dot = BMFDot(
      center: BMFCoordinate(lat, lon),
      radius: 8,
      color: Colors.red,
    );
    _selectedDotId = dot.id;
    await c.addDot(dot);
  }

  Future<void> _selectCoordinate({
    required double lat,
    required double lon,
    required String name,
  }) async {
    setState(() {
      _selectedLat = lat;
      _selectedLon = lon;
      _selectedName = name.trim();
    });
    await _refreshSelectDot();
  }

  void _onBMFMapCreated(BMFMapController controller) {
    _mapController = controller;
    _mapReady = true;

    controller.setMapOnClickedMapBlankCallback(
      callback: (BMFCoordinate coordinate) async {
        await _selectCoordinate(
          lat: coordinate.latitude,
          lon: coordinate.longitude,
          name: '',
        );
      },
    );
    controller.setMapOnClickedMapPoiCallback(
      callback: (BMFMapPoi poi) async {
        final pt = poi.pt;
        if (pt == null) return;
        await _selectCoordinate(
          lat: pt.latitude,
          lon: pt.longitude,
          name: poi.text ?? '',
        );
      },
    );

    final pending = _pendingCenter;
    if (pending != null) {
      _pendingCenter = null;
      _moveTo(pending.lat, pending.lon, zoom: 18);
    } else {
      _moveTo(_centerLat, _centerLon, zoom: 16);
    }
    _refreshSelectDot();
  }

  @override
  Widget build(BuildContext context) {
    final maxSuggestionHeight = MediaQuery.of(context).size.height * 0.28;
    return Scaffold(
      appBar: AppBar(title: const Text('选择签到位置')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchInputChanged,
                    onSubmitted: (_) =>
                        _searchPlaces(keyword: _searchController.text),
                    decoration: const InputDecoration(
                      hintText: '搜索地点',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching
                      ? null
                      : () => _searchPlaces(keyword: _searchController.text),
                  child: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('搜索'),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: math.min(300, maxSuggestionHeight),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.name.isEmpty ? '未命名地点' : item.name),
                    subtitle: Text(item.address),
                    onTap: () async {
                      await _selectCoordinate(
                        lat: item.latitude,
                        lon: item.longitude,
                        name: item.name,
                      );
                      await _moveTo(item.latitude, item.longitude, zoom: 18);
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                BMFMapWidget(
                  onBMFMapCreated: _onBMFMapCreated,
                  mapOptions: BMFMapOptions(
                    center: BMFCoordinate(_centerLat, _centerLon),
                    zoomLevel: 16,
                  ),
                ),
                if (_loadingLocation)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '定位中...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedLat == null || _selectedLon == null)
                  ? null
                  : _submit,
              child: Text(
                (_selectedLat == null || _selectedLon == null)
                    ? '请先点选地图位置'
                    : '使用该位置签到',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final lat = _selectedLat;
    final lon = _selectedLon;
    if (lat == null || lon == null) return;
    var locationName = _selectedName.trim();
    if (locationName.isEmpty) {
      locationName = await _promptLocationName() ?? '';
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      LocationPickResult(
        latitude: lat,
        longitude: lon,
        locationName: locationName,
      ),
    );
  }

  Future<String?> _promptLocationName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入地点名称'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '可留空'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('跳过'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}

class _PoiItem {
  const _PoiItem({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
}
