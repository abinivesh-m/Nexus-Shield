import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';

enum _MapViewMode { heatmap, pins }

class HotspotMapScreen extends StatefulWidget {
  const HotspotMapScreen({super.key});
  @override
  State<HotspotMapScreen> createState() => _HotspotMapScreenState();
}

class _HotspotMapScreenState extends State<HotspotMapScreen> {
  List<ScamHotspot> _hotspots = [];
  bool _loading = true;
  String? _error;
  String? _selectedCategory;
  final MapController _mapController = MapController();
  _MapViewMode _mode = _MapViewMode.heatmap;

  // Default camera centers on India so the map isn't blank before hotspots load.
  static const _initialCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final hotspots = await api.getHotspots(category: _selectedCategory);
      setState(() => _hotspots = hotspots);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _colorForCount(int count) {
    if (count >= 10) return AppColors.red;
    if (count >= 4) return AppColors.orange;
    return AppColors.green;
  }

  /// Green → yellow → orange → red gradient based on relative report volume.
  Color _heatColor(double t) {
    if (t < 0.33) return Color.lerp(AppColors.green, AppColors.yellow, t / 0.33)!;
    if (t < 0.66) return Color.lerp(AppColors.yellow, AppColors.orange, (t - 0.33) / 0.33)!;
    return Color.lerp(AppColors.orange, AppColors.red, (t - 0.66) / 0.34)!;
  }

  /// Layered, semi-transparent circles simulate heat-intensity without
  /// needing a native heatmap layer or any paid map service.
  List<CircleMarker> get _heatCircles {
    if (_hotspots.isEmpty) return [];
    final maxCount = _hotspots.map((h) => h.reportCount).reduce((a, b) => a > b ? a : b);

    final circles = <CircleMarker>[];
    for (final h in _hotspots) {
      final intensity = maxCount == 0 ? 0.0 : h.reportCount / maxCount;
      final color = _heatColor(intensity);
      final baseRadius = 4000 + intensity * 22000; // meters

      const layerFractions = [1.0, 0.65, 0.4, 0.18];
      const layerOpacities = [0.08, 0.14, 0.22, 0.34];

      for (var i = 0; i < layerFractions.length; i++) {
        circles.add(CircleMarker(
          point: LatLng(h.latitude, h.longitude),
          radius: baseRadius * layerFractions[i],
          useRadiusInMeter: true,
          color: color.withValues(alpha: layerOpacities[i]),
          borderStrokeWidth: 0,
        ));
      }
    }
    return circles;
  }

  List<Marker> get _pinMarkers => _hotspots.map((h) {
        final color = _colorForCount(h.reportCount);
        return Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => _showHotspotSheet(h),
            child: Icon(Icons.location_on, color: color, size: 34),
          ),
        );
      }).toList();

  /// Small always-tappable dots layered on top of the heatmap glow so users
  /// can tap through to hotspot details in either view mode.
  List<Marker> get _tapDots => _hotspots.map((h) {
        final color = _colorForCount(h.reportCount);
        return Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => _showHotspotSheet(h),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        );
      }).toList();

  void _showHotspotSheet(ScamHotspot h) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department, color: _colorForCount(h.reportCount)),
                  const SizedBox(width: 8),
                  Text(h.city,
                      style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 10),
              Text('${h.reportCount} report${h.reportCount == 1 ? '' : 's'} · Top category: ${h.topCategory}',
                  style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              const SizedBox(height: 14),
              ...h.categoryBreakdown.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13))),
                        Text('${e.value}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crime Hotspot Map'),
        centerTitle: false,
        actions: [_buildModeToggle()],
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 4.4,
                    minZoom: 3,
                    maxZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nexusshield.app',
                    ),
                    if (_mode == _MapViewMode.heatmap) CircleLayer(circles: _heatCircles),
                    MarkerLayer(markers: _mode == _MapViewMode.pins ? _pinMarkers : _tapDots),
                  ],
                ),
                if (_loading)
                  Container(
                    color: AppColors.bg.withValues(alpha: 0.6),
                    child: const Center(child: CircularProgressIndicator(color: AppColors.brand)),
                  ),
                if (_error != null)
                  Positioned(
                    left: 16, right: 16, top: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
                      ),
                      child: Text('Could not load hotspots: $_error',
                          style: GoogleFonts.inter(color: AppColors.brand, fontSize: 12)),
                    ),
                  ),
                Positioned(
                  left: 16, bottom: 16,
                  child: _buildSummaryChip(),
                ),
                Positioned(
                  right: 8, bottom: 16,
                  child: Column(
                    children: [
                      _zoomButton(Icons.add, () => _mapController.move(
                          _mapController.camera.center, _mapController.camera.zoom + 1)),
                      const SizedBox(height: 8),
                      _zoomButton(Icons.remove, () => _mapController.move(
                          _mapController.camera.center, _mapController.camera.zoom - 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
        ),
        child: Icon(icon, color: AppColors.textPrim, size: 18),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleButton('Heatmap', Icons.local_fire_department, _MapViewMode.heatmap),
            _toggleButton('Pins', Icons.place, _MapViewMode.pins),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String label, IconData icon, _MapViewMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final categories = <String?>[
      null, 'Digital Arrest Scam', 'UPI Fraud', 'OTP Scam', 'Phishing',
      'Investment Scam', 'Job Scam', 'Lottery Scam', 'Courier Scam',
    ];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: selected ? AppColors.brand : AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                cat ?? 'All Types',
                style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppColors.textSec,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryChip() {
    final total = _hotspots.fold<int>(0, (sum, h) => sum + h.reportCount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: _colorForCount(total), size: 16),
          const SizedBox(width: 6),
          Text('${_hotspots.length} hotspots · $total reports',
              style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}
