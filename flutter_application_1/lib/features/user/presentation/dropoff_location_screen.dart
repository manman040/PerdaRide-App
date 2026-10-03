import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_router.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../data/nominatim_geocoding_service.dart';

class DropoffLocationScreen extends StatefulWidget {
  const DropoffLocationScreen({
    super.key,
    required this.pickupPoint,
    required this.pickupLabel,
  });

  final LatLng pickupPoint;
  final String pickupLabel;

  @override
  State<DropoffLocationScreen> createState() => _DropoffLocationScreenState();
}

class _DropoffLocationScreenState extends State<DropoffLocationScreen> {
  PerdaMapController? _mapController;
  late final TextEditingController _searchController;
  final _geocoding = NominatimGeocodingService();
  late LatLng _dropoffPoint;
  String _dropoffLabel = '';
  bool _dropoffSelected = false;
  bool _isResolvingDropoff = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _dropoffPoint = LatLng(
      widget.pickupPoint.latitude + 0.005,
      widget.pickupPoint.longitude + 0.005,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: Text(
          copy.dropoffLocationTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                _infoBox(
                  context: context,
                  title: copy.pickupHistoryLabel,
                  value: widget.pickupLabel,
                  icon: Icons.trip_origin_rounded,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: copy.searchDropoffHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isResolvingDropoff
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _applyDropoffSearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                  ),
                  onSubmitted: (_) => _applyDropoffSearch(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _dropoffMap(),
                if (_dropoffSelected)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _infoBox(
                      context: context,
                      title: copy.dropoffTitleLabel,
                      value: _dropoffLabel.isEmpty
                          ? copy.resolvingLocationName
                          : _dropoffLabel,
                      icon: Icons.place_outlined,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dropoffSelected
                    ? () {
                        Navigator.of(context).pushNamed(
                          AppRouter.bookingPreview,
                          arguments: <String, dynamic>{
                            'pickupPoint': widget.pickupPoint,
                            'pickupLabel': widget.pickupLabel,
                            'dropoffPoint': _dropoffPoint,
                            'dropoffLabel': _dropoffLabel,
                          },
                        );
                      }
                    : null,
                child: Text(copy.confirmDropoffCta),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF68B1F), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropoffMap() {
    return PerdaMapView(
      key: const ValueKey('dropoff-map'),
      initialCenter: _dropoffPoint,
      initialZoom: 13.8,
      onMapCreated: (controller) => _mapController = controller,
      onTap: _onMapTap,
      markers: [
        PerdaMapMarker(
          id: 'pickup',
          point: widget.pickupPoint,
          color: const Color(0xFF2E7D32),
        ),
        if (_dropoffSelected)
          PerdaMapMarker(
            id: 'dropoff',
            point: _dropoffPoint,
            color: const Color(0xFFD32F2F),
          ),
      ],
    );
  }

  Future<void> _onMapTap(LatLng point) async {
    final copy = AppCopy.of(context);
    setState(() {
      _dropoffSelected = true;
      _dropoffPoint = point;
      _dropoffLabel = '';
      _isResolvingDropoff = true;
    });
    final label = await _geocoding.reverse(point);
    if (!mounted) return;
    setState(() {
      _dropoffLabel = label ?? _toLabel(point, copy.dropoffHistoryLabel);
      _isResolvingDropoff = false;
    });
  }

  void _syncDropoffMarker({required bool moveCamera}) {
    if (!moveCamera) return;
    _mapController?.animateCamera(_dropoffPoint, 16);
  }

  Future<void> _applyDropoffSearch() async {
    final copy = AppCopy.of(context);
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isResolvingDropoff = true;
    });
    final result = await _geocoding.searchFirst(query);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _isResolvingDropoff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.dropoffNotFoundError)),
      );
      return;
    }
    setState(() {
      _dropoffSelected = true;
      _dropoffPoint = result.point;
      _dropoffLabel = result.name;
      _isResolvingDropoff = false;
    });
    _syncDropoffMarker(moveCamera: true);
  }

  String _toLabel(LatLng point, String prefix) {
    return '$prefix: ${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
  }
}
