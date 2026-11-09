import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/payment_transaction_model.dart';
import '../../repositories/advertisement_repository.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final bool isAdminView;

  const TransactionHistoryScreen({
    super.key,
    this.isAdminView = false,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<PaymentTransactionModel> _transactions = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AdvertisementRepository>();
      final statusParam = _selectedStatus == 'all' ? null : _selectedStatus;

      final list = widget.isAdminView
          ? await repo.getAdminTransactions(status: statusParam)
          : await repo.getEmployerTransactions(status: statusParam);

      if (mounted) {
        setState(() {
          _transactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showReceiptDialog(PaymentTransactionModel tx) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.indigo.shade700),
            const SizedBox(width: 8),
            const Text('Payment Receipt', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _receiptLine('Receipt No:', tx.receiptNumber ?? 'Pending'),
            _receiptLine('Reference:', tx.transactionReference),
            _receiptLine('Gateway:', tx.paymentMethod.toUpperCase()),
            _receiptLine(
              'Amount:',
              '${(tx.confirmedAmountEtb ?? tx.expectedAmountEtb).toStringAsFixed(2)} ETB',
              isBold: true,
            ),
            _receiptLine('Status:', tx.paymentStatus.toUpperCase()),
            if (tx.verifiedAt != null)
              _receiptLine('Settled At:', dateFormat.format(tx.verifiedAt!.toLocal())),
            if (tx.campaignTitle != null)
              _receiptLine('Campaign:', tx.campaignTitle!),
            if (tx.failureReason != null)
              _receiptLine('Failure Reason:', tx.failureReason!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (widget.isAdminView && tx.isSuccessful)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showRefundDialog(tx);
              },
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Issue Refund'),
            ),
        ],
      ),
    );
  }

  void _showRefundDialog(PaymentTransactionModel tx) {
    final amountController = TextEditingController(
      text: (tx.confirmedAmountEtb ?? tx.expectedAmountEtb).toStringAsFixed(2),
    );
    final reasonController = TextEditingController(
      text: 'Advertiser requested campaign cancellation and refund.',
    );
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.replay, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'Authorize Refund',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction: ${tx.transactionReference}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Refund Amount (ETB)',
                    prefixText: 'ETB ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Audit Reason / Notes',
                    hintText: 'Enter reason for issuing refund...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid refund amount.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isProcessing = true);
                      final repo = context.read<AdvertisementRepository>();
                      final success = await repo.refundTransaction(
                        tx.transactionReference,
                        amount,
                        reasonController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refund processed and recorded successfully.'),
                              backgroundColor: Color(0xFF0D6B4F),
                            ),
                          );
                          _loadTransactions();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                repo.lastErrorMessage ?? 'Refund failed to process.',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Authorize Refund'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptLine(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? Colors.indigo.shade700 : Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdminView ? 'Admin Transactions' : 'Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All Transactions'),
                const SizedBox(width: 8),
                _filterChip('successful', 'Successful'),
                const SizedBox(width: 8),
                _filterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _filterChip('failed', 'Failed'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadTransactions,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payment_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No payment transactions found.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transactions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final tx = _transactions[index];
                              return _buildTransactionCard(theme, tx);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = statusKey;
          });
          _loadTransactions();
        }
      },
      selectedColor: Colors.indigo.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.indigo.shade900 : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTransactionCard(ThemeData theme, PaymentTransactionModel tx) {
    Color statusColor;
    IconData statusIcon;

    if (tx.isSuccessful) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (tx.isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showReceiptDialog(tx),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            tx.campaignTitle ?? 'Campaign Advertisement',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${tx.expectedAmountEtb.toStringAsFixed(2)} ETB',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ref: ${tx.transactionReference}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tx.createdAt != null
                              ? dateFormat.format(tx.createdAt!.toLocal())
                              : 'Recent',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.paymentStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (widget.isAdminView && tx.isSuccessful) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _showRefundDialog(tx),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFDC2626).withAlpha(100),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.replay,
                                          color: Color(0xFFDC2626), size: 10),
                                      SizedBox(width: 2),
                                      Text(
                                        'REFUND',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
