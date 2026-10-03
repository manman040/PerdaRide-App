import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_router.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../../booking/data/booking_repository.dart';
import '../data/osrm_routing_service.dart';

class BookingPreviewScreen extends StatefulWidget {
  const BookingPreviewScreen({
    super.key,
    required this.pickupPoint,
    required this.pickupLabel,
    required this.dropoffPoint,
    required this.dropoffLabel,
    this.existingBookingId,
    this.initialPaymentMethod,
    this.initialPackageLabel,
  });

  final LatLng pickupPoint;
  final String pickupLabel;
  final LatLng dropoffPoint;
  final String dropoffLabel;
  final String? existingBookingId;
  final String? initialPaymentMethod;
  final String? initialPackageLabel;

  @override
  State<BookingPreviewScreen> createState() => _BookingPreviewScreenState();
}

class _BookingPreviewScreenState extends State<BookingPreviewScreen> {
  static const _paymentOptions = ['Cash', 'QR Manual to driver'];
  static const _packageOptions = [
    'Package A (1-4 passengers)',
    'Package B (5-8 passengers)',
  ];

  final _bookingRepository = BookingRepository();
  final _routingService = OsrmRoutingService();
  late String? _selectedPayment = widget.initialPaymentMethod;
  late String? _selectedPackage = widget.initialPackageLabel;
  bool _isSubmitting = false;
  List<LatLng> _routePoints = [];
  OsrmRouteResult? _routeResult;

  // Local placeholders only, used until _loadFareSettings() returns -- the
  // admin dashboard's Fare Settings page is the actual source of truth
  // (fareSettings/categoryA and /categoryB in Firebase), not these.
  FareSettings _categoryASettings =
      const FareSettings(baseFare: 2.0, perKm: 1.2, bookingFee: 1.0);
  FareSettings _categoryBSettings =
      const FareSettings(baseFare: 3.0, perKm: 1.5, bookingFee: 1.0);

  bool get _isEditing => widget.existingBookingId != null;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _loadFareSettings();
  }

  Future<void> _loadFareSettings() async {
    final categoryA = await _bookingRepository.getFareSettings('categoryA');
    final categoryB = await _bookingRepository.getFareSettings('categoryB');
    if (!mounted) return;
    setState(() {
      _categoryASettings = categoryA;
      _categoryBSettings = categoryB;
    });
  }

  double get _distanceKm {
    final routeMeters = _routeResult?.distanceMeters;
    if (routeMeters != null && routeMeters > 0) {
      return routeMeters / 1000;
    }
    const distance = Distance();
    final meter = distance.as(
      LengthUnit.Meter,
      widget.pickupPoint,
      widget.dropoffPoint,
    );
    return meter / 1000;
  }

  /// Package selection ("Package A (1-4 passengers)" / "Package B (5-8
  /// passengers)") doubles as the ride category -- same split the driver
  /// side already uses to filter available jobs by vehicle size, so it maps
  /// directly onto the admin dashboard's Category A / Category B rates
  /// instead of introducing a separate category concept.
  FareSettings get _activeFareSettings {
    final package = _selectedPackage ?? _packageOptions.first;
    return package.startsWith('Package B')
        ? _categoryBSettings
        : _categoryASettings;
  }

  double get _estimatedFare {
    final subtotal = _activeFareSettings.totalFor(_distanceKm);
    // Round to the nearest 10 sen -- easier to pay/give change for in cash
    // than an odd amount like RM12.24 (becomes RM12.20).
    final roundedToDime = (subtotal * 10).round() / 10;
    return double.parse(roundedToDime.toStringAsFixed(2));
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
          _isEditing ? copy.editBookingTitle : copy.bookingPreviewTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: _previewMap(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                _routeCard(context),
                const SizedBox(height: 14),
                _fareCard(context),
                const SizedBox(height: 14),
                _selectorCard(
                  context: context,
                  label: copy.paymentMethodLabel,
                  value: _selectedPayment ?? copy.choosePaymentMethodPlaceholder,
                  onTap: _choosePaymentMethod,
                ),
                const SizedBox(height: 12),
                _selectorCard(
                  context: context,
                  label: copy.packageTypeLabel,
                  value: _selectedPackage ?? copy.selectPackagePlaceholder,
                  onTap: _choosePackage,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: (_selectedPayment != null &&
                          _selectedPackage != null &&
                          !_isSubmitting)
                      ? _confirmBooking
                      : null,
                  child: Text(
                    _isSubmitting
                        ? copy.bookingSubmittingCta
                        : _isEditing
                        ? copy.saveChangesCta
                        : copy.confirmBookingCta,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRoute() async {
    final result = await _routingService.getDrivingRouteResult(
      from: widget.pickupPoint,
      to: widget.dropoffPoint,
    );
    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _routePoints = result.points;
    });
  }

  Widget _previewMap() {
    final points = _routePoints.isEmpty
        ? [widget.pickupPoint, widget.dropoffPoint]
        : _routePoints;
    return PerdaMapView(
      key: const ValueKey('booking-preview-map'),
      initialCenter: LatLng(
        (widget.pickupPoint.latitude + widget.dropoffPoint.latitude) / 2,
        (widget.pickupPoint.longitude + widget.dropoffPoint.longitude) / 2,
      ),
      initialZoom: 13.5,
      markers: [
        PerdaMapMarker(
          id: 'pickup',
          point: widget.pickupPoint,
          color: const Color(0xFF2E7D32),
        ),
        PerdaMapMarker(
          id: 'dropoff',
          point: widget.dropoffPoint,
          color: const Color(0xFFD32F2F),
        ),
      ],
      polylines: [
        PerdaMapPolyline(
          id: 'route',
          points: points,
          color: const Color(0xFF2CB67D),
        ),
      ],
    );
  }

  Future<void> _confirmBooking() async {
    final copy = AppCopy.of(context);
    final payment = _selectedPayment;
    final package = _selectedPackage;
    if (payment == null || package == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fareLabel = 'RM ${_estimatedFare.toStringAsFixed(2)}';
      final distanceLabel =
          _routeResult?.distanceLabel ?? '${_distanceKm.toStringAsFixed(1)} km';

      final String bookingId;
      if (_isEditing) {
        bookingId = widget.existingBookingId!;
        await _bookingRepository.updateBookingDetails(
          bookingId: bookingId,
          paymentMethod: payment,
          packageLabel: package,
          fareLabel: fareLabel,
          distanceLabel: distanceLabel,
        );
      } else {
        bookingId = await _bookingRepository.createBooking(
          pickupPoint: widget.pickupPoint,
          pickupLabel: widget.pickupLabel,
          dropoffPoint: widget.dropoffPoint,
          dropoffLabel: widget.dropoffLabel,
          paymentMethod: payment,
          packageLabel: package,
          fareLabel: fareLabel,
          distanceLabel: distanceLabel,
        );
      }

      if (!mounted) return;
      final statusArguments = <String, dynamic>{
        'bookingId': bookingId,
        'pickupPoint': widget.pickupPoint,
        'pickupLabel': widget.pickupLabel,
        'dropoffPoint': widget.dropoffPoint,
        'dropoffLabel': widget.dropoffLabel,
        'paymentMethod': payment,
        'packageLabel': package,
        'fareLabel': fareLabel,
      };
      if (_isEditing) {
        Navigator.of(context).pushReplacementNamed(
          AppRouter.userBookingStatus,
          arguments: statusArguments,
        );
      } else {
        Navigator.of(context).pushNamed(
          AppRouter.userBookingStatus,
          arguments: statusArguments,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '${copy.failedToSaveChangesError} $e'
                : '${copy.failedToCreateBookingError} $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _routeCard(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _routeRow(
            context: context,
            icon: Icons.trip_origin_rounded,
            iconBg: const Color(0xFF2E7D32).withValues(alpha: 0.14),
            iconColor: const Color(0xFF2E7D32),
            title: copy.pickupHistoryLabel,
            value: widget.pickupLabel,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(height: 18, color: theme.dividerColor),
          ),
          _routeRow(
            context: context,
            icon: Icons.place_rounded,
            iconBg: const Color(0xFFD84315).withValues(alpha: 0.14),
            iconColor: const Color(0xFFD84315),
            title: copy.dropoffTitleLabel,
            value: widget.dropoffLabel,
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
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
    );
  }

  Widget _fareCard(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFFF68B1F), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${copy.estimatedFareLabel} (${_routeResult?.distanceLabel ?? '${_distanceKm.toStringAsFixed(1)} km'})',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RM ${_estimatedFare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFD35400),
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                if (_routeResult != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${copy.etaLabel} ${_routeResult!.etaLabel}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorCard({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choosePaymentMethod() async {
    final copy = AppCopy.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.choosePaymentMethodTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ..._paymentOptions.map(
                  (method) => ListTile(
                    title: Text(method),
                    onTap: () => Navigator.pop(context, method),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _selectedPayment = selected);
  }

  Future<void> _choosePackage() async {
    final copy = AppCopy.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.selectPackageTitle,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ..._packageOptions.map(
                  (pkg) => ListTile(
                    title: Text(pkg),
                    onTap: () => Navigator.pop(context, pkg),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _selectedPackage = selected);
  }
}
