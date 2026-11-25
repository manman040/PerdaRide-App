import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ToyyibPayService {
  ToyyibPayService({http.Client? client}) : _client = client ?? http.Client();

  static const String backendBaseUrl = 'https://urbandrive-toyyibpay.onrender.com';
  final http.Client _client;

  Future<ToyyibPayBillResult> createBill({
    required String driverId,
    required double amount,
    required String reference,
    required String driverName,
    required String driverEmail,
    required String driverPhone,
  }) async {
    final safeAmount = amount < 1 ? 1.0 : amount;
    final encodedName = Uri.encodeComponent(
      driverName.isEmpty ? 'Driver' : driverName,
    );
    final encodedRef = Uri.encodeComponent(reference);
    final encodedDriverId = Uri.encodeComponent(driverId);

    final returnUrl =
        '$backendBaseUrl/api/toyyibpay/success?amount=${safeAmount.toStringAsFixed(2)}&driverName=$encodedName&reference=$encodedRef&driverId=$encodedDriverId&t=${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, dynamic>{
      'amount': safeAmount,
      'driverId': driverId,
      'reference': reference,
      'returnUrl': returnUrl,
      'callbackUrl': '$backendBaseUrl/api/toyyibpay/callback',
      'billTo': driverName.isEmpty ? 'Driver' : driverName,
      'billEmail': driverEmail.isEmpty ? '$driverId@perdaride.app' : driverEmail,
      'billName': 'Pay Commission',
      'billDescription': 'Pay commission to company Urban Drive',
      'billPhone': _cleanPhone(driverPhone),
    };

    final uri = Uri.parse('$backendBaseUrl/api/toyyibpay/create-bill');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Create bill failed (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map) {
      throw Exception('Invalid response from payment server.');
    }

    final paymentUrl = (body['paymentUrl'] ?? body['payment_url'] ?? '').toString();
    final billCode = (body['billCode'] ?? body['billcode'] ?? '').toString();

    if (paymentUrl.isEmpty) {
      throw Exception('Payment URL not returned by server.');
    }

    return ToyyibPayBillResult(
      paymentUrl: paymentUrl,
      billCode: billCode,
      reference: reference,
      amount: safeAmount,
    );
  }

  Future<void> openPaymentPage(String paymentUrl) async {
    final uri = Uri.parse(paymentUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Unable to open payment URL.');
  }

  String _cleanPhone(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isEmpty) return '0123456789';
    if (onlyDigits.length < 9) return '0123456789';
    return onlyDigits;
  }
}

class ToyyibPayBillResult {
  const ToyyibPayBillResult({
    required this.paymentUrl,
    required this.billCode,
    required this.reference,
    required this.amount,
  });

  final String paymentUrl;
  final String billCode;
  final String reference;
  final double amount;
}
