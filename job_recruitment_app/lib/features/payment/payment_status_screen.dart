import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/payment_transaction_model.dart';
import '../../repositories/advertisement_repository.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String transactionReference;
  final int campaignId;
  final PaymentTransactionModel? initialTransaction;

  const PaymentStatusScreen({
    super.key,
    required this.transactionReference,
    required this.campaignId,
    this.initialTransaction,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  PaymentTransactionModel? _transaction;
  bool _isChecking = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _transaction = widget.initialTransaction;
    _verifyStatus();

    // Poll every 5 seconds up to 6 times if pending
    int pollCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      pollCount++;
      if (_transaction?.isSuccessful == true || pollCount > 6) {
        timer.cancel();
      } else {
        _verifyStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isChecking = true;
        _errorMessage = null;
      });
    }

    try {
      final repo = context.read<AdvertisementRepository>();
      final updated = await repo.verifyPayment(widget.transactionReference);

      if (mounted) {
        setState(() {
          _isChecking = false;
          if (updated != null) {
            _transaction = updated;
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _isChecking = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = _transaction;

    return PopScope(
      canPop: tx?.isSuccessful == true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment Verification'),
          automaticallyImplyLeading: tx?.isSuccessful == true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tx?.isSuccessful == true)
                  _buildSuccessView(theme, tx!)
                else if (tx?.isFailed == true)
                  _buildFailedView(theme, tx!)
                else
                  _buildPendingView(theme, tx),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingView(ThemeData theme, PaymentTransactionModel? tx) {
    return Column(
      children: [
        const SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Awaiting Gateway Confirmation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Please complete the transaction in your Chapa / Telebirr / CBE payment window.\nWe are securely listening for official gateway settlement confirmation.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _buildDetailRow('Reference', widget.transactionReference),
              const Divider(height: 16),
              _buildDetailRow(
                'Amount',
                '${tx?.expectedAmountEtb.toStringAsFixed(2) ?? "---"} ETB',
              ),
              const Divider(height: 16),
              _buildDetailRow('Provider', tx?.paymentMethod.toUpperCase() ?? 'CHAPA'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isChecking ? null : () => _verifyStatus(),
            icon: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isChecking ? 'Verifying...' : 'Check Status Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Return to Campaigns'),
        ),
      ],
    );
  }

  Widget _buildSuccessView(ThemeData theme, PaymentTransactionModel tx) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Confirmed!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your advertising payment has been settled and verified.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Digital Receipt Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'OFFICIAL RECEIPT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SETTLED (ETB)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildDetailRow('Receipt No.', tx.receiptNumber ?? 'RCP-ISSUED'),
                const Divider(height: 14),
                _buildDetailRow('Transaction Ref', tx.transactionReference),
                const Divider(height: 14),
                _buildDetailRow('Payment Gateway', tx.paymentMethod.toUpperCase()),
                const Divider(height: 14),
                _buildDetailRow(
                  'Confirmed Amount',
                  '${(tx.confirmedAmountEtb ?? tx.expectedAmountEtb).toStringAsFixed(2)} ETB',
                  isHighlighted: true,
                ),
                const Divider(height: 14),
                _buildDetailRow(
                  'Settled At',
                  tx.verifiedAt != null
                      ? dateFormat.format(tx.verifiedAt!.toLocal())
                      : dateFormat.format(DateTime.now()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to My Campaigns'),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedView(ThemeData theme, PaymentTransactionModel tx) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close, color: Colors.red.shade700, size: 44),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Unsuccessful',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          tx.failureReason ?? 'The payment could not be completed or was cancelled.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry Payment'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? Colors.indigo.shade700 : Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
