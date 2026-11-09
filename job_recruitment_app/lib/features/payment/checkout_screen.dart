import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/advertisement_model.dart';
import '../../models/advertising_package_model.dart';
import '../../repositories/advertisement_repository.dart';
import '../../services/auth_service.dart';
import 'payment_status_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final AdvertisementModel campaign;
  final AdvertisingPackageModel package;

  const CheckoutScreen({
    super.key,
    required this.campaign,
    required this.package,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedProvider = 'chapa';
  bool _isLoading = false;
  Map<String, dynamic> _providerStatuses = {};

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final authUser = context.read<AuthService>().currentUser;
    _nameController = TextEditingController(text: authUser?.name ?? '');
    _emailController = TextEditingController(text: authUser?.email ?? '');
    _phoneController = TextEditingController(text: authUser?.phone ?? '');

    _fetchPaymentMethods();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final repo = context.read<AdvertisementRepository>();
      final methods = await repo.getPaymentMethods();
      if (mounted) {
        setState(() {
          _providerStatuses = methods;
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to fetch payment method statuses: $e',
        name: 'CheckoutScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  double get _amountToPay => widget.package.priceEtb;

  Future<void> _processCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    final providerConfigured = _providerStatuses[_selectedProvider]?['configured'] == true;
    if (!providerConfigured && _selectedProvider != 'chapa') {
      _showErrorSnackBar(
        'Direct $_selectedProvider integration is awaiting enterprise merchant keys. Please select Chapa (which supports Telebirr, CBE Birr & Cards).',
      );
      setState(() => _selectedProvider = 'chapa');
      return;
    }

    final repo = context.read<AdvertisementRepository>();

    setState(() {
      _isLoading = true;
    });

    try {
      final transaction = await repo.initiatePayment(
        advertisementId: widget.campaign.id,
        paymentMethod: _selectedProvider,
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (transaction != null && transaction.checkoutUrl != null) {
        final uri = Uri.parse(transaction.checkoutUrl!);
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          _showCheckoutUrlFallback(transaction.checkoutUrl!);
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentStatusScreen(
              transactionReference: transaction.transactionReference,
              campaignId: widget.campaign.id,
              initialTransaction: transaction,
            ),
          ),
        );
      } else {
        final err = repo.lastErrorMessage ?? 'Failed to initialize payment checkout.';
        _showErrorSnackBar(err);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Checkout error: $e');
    }
  }

  /// Shown when the external payment checkout URL cannot be opened (e.g. no
  /// browser/handler available on the device). Surfaces the raw URL so the user
  /// can still reach the payment page manually.
  void _showCheckoutUrlFallback(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open the payment page automatically. Open this link manually:\n$url'),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 12),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Copy Link',
          textColor: Colors.white,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Payment link copied to clipboard.'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProviderOnboardingInfo(String providerTitle, Map<String, dynamic> data) {
    final checklist = data['onboarding_checklist'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$providerTitle Status',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['status_message']?.toString() ?? 'Pending Merchant Integration',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            if (checklist.isNotEmpty) ...[
              const Text(
                'Merchant Onboarding Requirements:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...checklist.map(
                (step) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• $step',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Select Chapa to complete payment via Telebirr or CBE Birr immediately.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got It'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              _buildOrderSummaryCard(theme),
              const SizedBox(height: 20),

              // Payment Provider Selection
              Text(
                'Select Payment Gateway',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Direct ETB settlement supported through official Ethiopian gateways.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              _buildPaymentProviderOption(
                providerKey: 'chapa',
                title: 'Chapa Payment Gateway',
                subtitle: 'Telebirr, CBE Birr, Visa, Mastercard, Local Cards',
                icon: Icons.payment,
                badgeText: 'Active',
                badgeColor: Colors.green,
                isRecommended: true,
              ),
              const SizedBox(height: 10),

              _buildPaymentProviderOption(
                providerKey: 'telebirr',
                title: 'Telebirr (Ethio Telecom)',
                subtitle: 'Direct Merchant C2B USSD & H5 Push',
                icon: Icons.phone_android,
                badgeText: _providerStatuses['telebirr']?['configured'] == true
                    ? 'Active'
                    : 'Onboarding Required',
                badgeColor: _providerStatuses['telebirr']?['configured'] == true
                    ? Colors.green
                    : Colors.amber.shade700,
                isRecommended: false,
              ),
              const SizedBox(height: 10),

              _buildPaymentProviderOption(
                providerKey: 'cbe_birr',
                title: 'CBE Birr (Commercial Bank of Ethiopia)',
                subtitle: 'Direct Till & Enterprise Gateway',
                icon: Icons.account_balance,
                badgeText: _providerStatuses['cbe_birr']?['configured'] == true
                    ? 'Active'
                    : 'Onboarding Required',
                badgeColor: _providerStatuses['cbe_birr']?['configured'] == true
                    ? Colors.green
                    : Colors.amber.shade700,
                isRecommended: false,
              ),
              const SizedBox(height: 24),

              // Payer Details
              Text(
                'Billing & Receipt Contact',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Contact / Organization Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter contact name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Receipt Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter receipt email';
                  if (!val.contains('@')) return 'Please enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. +2519...) *',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 24),

              // Security Trust Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green.shade700, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Zero-Trust Backend Verification: Campaigns activate only upon authenticated payment confirmation from verified Ethiopian gateways.',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pay ${_amountToPay.toStringAsFixed(2)} ETB',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campaign Order',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.package.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.campaign.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Category: ${widget.campaign.category} • Placement: ${widget.campaign.placement}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Payable Amount',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_amountToPay.toStringAsFixed(2)} ETB',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentProviderOption({
    required String providerKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required bool isRecommended,
  }) {
    final isSelected = _selectedProvider == providerKey;
    final isConfigured = _providerStatuses[providerKey]?['configured'] ?? (providerKey == 'chapa');

    return InkWell(
      onTap: () {
        if (!isConfigured && providerKey != 'chapa') {
          _showProviderOnboardingInfo(title, _providerStatuses[providerKey] ?? {});
          return;
        }
        setState(() {
          _selectedProvider = providerKey;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? Colors.indigo.shade50.withAlpha(50) : Colors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: providerKey,
              groupValue: _selectedProvider,
              onChanged: isConfigured || providerKey == 'chapa'
                  ? (val) {
                      if (val != null) {
                        setState(() => _selectedProvider = val);
                      }
                    }
                  : null,
            ),
            Icon(icon, color: Colors.indigo.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
