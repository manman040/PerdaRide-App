class DriverTripRecord {
  const DriverTripRecord({
    required this.passengerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.dateLabel,
    required this.timeLabel,
    required this.fare,
    required this.commission,
  });

  final String passengerName;
  final String pickupAddress;
  final String dropoffAddress;
  final String dateLabel;
  final String timeLabel;
  final double fare;
  final double commission;

  String get fareLabel => 'RM${fare.toStringAsFixed(2)}';

  String get commissionLabel => 'RM${commission.toStringAsFixed(2)}';
}

class DriverDemoData {
  static const history = <DriverTripRecord>[
    DriverTripRecord(
      passengerName: 'kuru',
      pickupAddress: 'GF95+9G, 13100 Kepala Batas, Penang, Malaysia',
      dropoffAddress:
          'Lot 20976, Jln Paya Keladi, Tengah, 13200 Kepala Batas, Penang, Malaysia',
      dateLabel: '14 May 2026',
      timeLabel: '11:17 am',
      fare: 6.20,
      commission: 1.24,
    ),
    DriverTripRecord(
      passengerName: 'aiman',
      pickupAddress:
          'Jalan Perda Tech, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dropoffAddress:
          '1869, Jalan Sungai Kechil, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dateLabel: '04 Dec 2025',
      timeLabel: '10:57 am',
      fare: 7.00,
      commission: 1.40,
    ),
    DriverTripRecord(
      passengerName: 'aiman',
      pickupAddress:
          'Jalan Perda Tech, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dropoffAddress:
          'Lot 5724B, Jalan Besar, Air Lintas, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dateLabel: '04 Dec 2025',
      timeLabel: '10:31 am',
      fare: 11.80,
      commission: 2.36,
    ),
    DriverTripRecord(
      passengerName: 'aiman',
      pickupAddress: 'Nibong Tebal, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dropoffAddress:
          'Taman Ilmu, Jalan Transkrian, 14300 Nibong Tebal, Pulau Pinang, Malaysia',
      dateLabel: '04 Dec 2025',
      timeLabel: '10:09 am',
      fare: 9.00,
      commission: 1.80,
    ),
  ];

  static double get totalEarnings =>
      history.fold(0, (sum, item) => sum + item.fare);

  static double get totalCommission =>
      history.fold(0, (sum, item) => sum + item.commission);
}

