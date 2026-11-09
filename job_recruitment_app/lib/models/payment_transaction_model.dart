class PaymentTransactionModel {
  final int id;
  final String transactionReference;
  final String? merchantReference;
  final String? providerReference;
  final String? checkoutUrl;
  final String paymentMethod;
  final double expectedAmountEtb;
  final double? confirmedAmountEtb;
  final String currency;
  final String paymentStatus;
  final String? receiptNumber;
  final DateTime? verifiedAt;
  final String? failureReason;
  final DateTime? createdAt;
  final String? campaignTitle;
  final String? packageName;

  PaymentTransactionModel({
    required this.id,
    required this.transactionReference,
    this.merchantReference,
    this.providerReference,
    this.checkoutUrl,
    required this.paymentMethod,
    required this.expectedAmountEtb,
    this.confirmedAmountEtb,
    this.currency = 'ETB',
    required this.paymentStatus,
    this.receiptNumber,
    this.verifiedAt,
    this.failureReason,
    this.createdAt,
    this.campaignTitle,
    this.packageName,
  });

  bool get isSuccessful => paymentStatus.toLowerCase() == 'successful';
  bool get isPending => paymentStatus.toLowerCase() == 'pending';
  bool get isFailed =>
      ['failed', 'cancelled', 'expired'].contains(paymentStatus.toLowerCase());
  bool get isRefunded => paymentStatus.toLowerCase() == 'refunded';

  String get formattedAmount =>
      '${expectedAmountEtb.toStringAsFixed(2)} $currency';

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    String? cTitle;
    String? pName;

    if (json['advertisement'] is Map) {
      cTitle = json['advertisement']['title']?.toString();
    } else if (json['campaign_title'] != null) {
      cTitle = json['campaign_title'].toString();
    }

    if (json['package'] is Map) {
      pName = json['package']['name']?.toString();
    } else if (json['package_name'] != null) {
      pName = json['package_name'].toString();
    }

    return PaymentTransactionModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      transactionReference: json['transaction_reference']?.toString() ?? '',
      merchantReference: json['merchant_reference']?.toString(),
      providerReference: json['provider_reference']?.toString(),
      checkoutUrl: json['checkout_url']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'chapa',
      expectedAmountEtb:
          double.tryParse('${json['expected_amount_etb']}') ?? 0.0,
      confirmedAmountEtb: json['confirmed_amount_etb'] != null
          ? double.tryParse('${json['confirmed_amount_etb']}')
          : null,
      currency: json['currency']?.toString() ?? 'ETB',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      receiptNumber: json['receipt_number']?.toString(),
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
      failureReason: json['failure_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      campaignTitle: cTitle,
      packageName: pName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_reference': transactionReference,
      'merchant_reference': merchantReference,
      'provider_reference': providerReference,
      'checkout_url': checkoutUrl,
      'payment_method': paymentMethod,
      'expected_amount_etb': expectedAmountEtb,
      'confirmed_amount_etb': confirmedAmountEtb,
      'currency': currency,
      'payment_status': paymentStatus,
      'receipt_number': receiptNumber,
      'verified_at': verifiedAt?.toIso8601String(),
      'failure_reason': failureReason,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
