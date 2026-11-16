import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

import '../../data/procurement/procurement_api_service.dart';
import '../../data/procurement/procurement_models.dart';
import '../../services/user_session_manager.dart';
import '../../widgets/mobile_app_header.dart';

class ProcurementWalletScreen extends StatefulWidget {
  const ProcurementWalletScreen({super.key});

  @override
  State<ProcurementWalletScreen> createState() =>
      _ProcurementWalletScreenState();
}

class _ProcurementWalletScreenState extends State<ProcurementWalletScreen> {
  final ProcurementApiService _api = ProcurementApiService();

  ProcurementWalletData? _walletData;
  bool _isLoading = true;
  String? _error;
  String _filterType = 'ALL'; // ALL | EXPENSE | DISBURSEMENT

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = UserSessionManager.instance.token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    try {
      final data = await _api.fetchWallet(token);
      if (mounted) {
        setState(() {
          _walletData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load wallet';
        });
      }
    }
  }

  void _openExpenseLogger() {
    if (_walletData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogExpenseSheet(
        activeProjects: _walletData!.activeProjects,
        onSuccess: () {
          Navigator.of(context).pop();
          _loadWallet();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense logged successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: MobileAppHeader(
        title: 'Procurement Wallet',
        onRefresh: _loadWallet,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExpenseLogger,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Log Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFoldingCube(
          color: Color(0xFF2563EB),
          size: 36.0,
        ),
      );
    }

    if (_error != null || _walletData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error ?? 'Could not load wallet'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWallet,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final data = _walletData!;
    final w = data.wallet;

    final filteredTxs = data.transactions.where((tx) {
      if (_filterType == 'EXPENSE') return tx.isExpense;
      if (_filterType == 'DISBURSEMENT') return tx.isDisbursement;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Gradient Wallet Card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Company Advance Float',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Advance Balance in Hand
                Text(
                  '৳ ${NumberFormat('#,##0').format(w.advanceBalance)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cash in Hand / Pocket balance',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const Divider(color: Colors.white12, height: 28),

                // Lower Stats Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Reimbursement',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳ ${NumberFormat('#,##0').format(w.pendingReimbursement)}',
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Expensed',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳ ${NumberFormat('#,##0').format(w.totalSpent)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick Log Button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openExpenseLogger,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text(
                'Log New Purchase / Transport Expense',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Transaction Section Title & Filter ───────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  _TxFilterChip(
                    label: 'All',
                    selected: _filterType == 'ALL',
                    onTap: () => setState(() => _filterType = 'ALL'),
                  ),
                  const SizedBox(width: 4),
                  _TxFilterChip(
                    label: 'Expenses',
                    selected: _filterType == 'EXPENSE',
                    onTap: () => setState(() => _filterType = 'EXPENSE'),
                  ),
                  const SizedBox(width: 4),
                  _TxFilterChip(
                    label: 'Advance',
                    selected: _filterType == 'DISBURSEMENT',
                    onTap: () => setState(() => _filterType = 'DISBURSEMENT'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Transactions List ────────────────────────────────────
          if (filteredTxs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 44, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No transactions recorded',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Log Expense" to record daily purchases.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ...filteredTxs.map((tx) => _TransactionTile(tx: tx)),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _TxFilterChip extends StatelessWidget {
  const _TxFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final WalletTransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final isDisbursement = tx.isDisbursement;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDisbursement
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDisbursement
                  ? Icons.arrow_downward_rounded
                  : Icons.shopping_bag_outlined,
              size: 20,
              color: isDisbursement
                  ? const Color(0xFF059669)
                  : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),

          // Particular & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.particular,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                if (tx.leadName != null) ...[
                  Text(
                    'Project: ${tx.leadName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: [
                    Text(
                      '${tx.paymentMethod} • ${DateFormat('dd MMM').format(tx.date)}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 6),
                    if (tx.isFromPersonalPocket)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Personal Pocket',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDisbursement ? '+' : '-'}৳${NumberFormat('#,##0').format(tx.totalAmount)}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDisbursement
                      ? const Color(0xFF059669)
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              _TxStatusPill(status: tx.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxStatusPill extends StatelessWidget {
  const _TxStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'SETTLED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Settled';
        break;
      case 'APPROVED':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'Approved';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFFF1F2);
        fg = const Color(0xFFE11D48);
        label = 'Rejected';
        break;
      case 'PENDING':
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Expense Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _LogExpenseSheet extends StatefulWidget {
  const _LogExpenseSheet({
    required this.activeProjects,
    required this.onSuccess,
  });

  final List<ActiveProjectModel> activeProjects;
  final VoidCallback onSuccess;

  @override
  State<_LogExpenseSheet> createState() => _LogExpenseSheetState();
}

class _LogExpenseSheetState extends State<_LogExpenseSheet> {
  final ProcurementApiService _api = ProcurementApiService();
  final _formKey = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController(text: '0');
  final _particularCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();

  String _paidFrom = 'COMPANY_ADVANCE'; // COMPANY_ADVANCE | PERSONAL_POCKET
  String _paymentMethod = 'CASH';
  String _category = 'RAW_MATERIALS';
  ActiveProjectModel? _selectedProject;
  bool _submitting = false;

  final List<Map<String, String>> _categories = const [
    {'value': 'RAW_MATERIALS', 'label': 'Raw Materials (Wood, Board)'},
    {'value': 'HARDWARE', 'label': 'Hardware & Fittings'},
    {'value': 'TRANSPORT_LABOR', 'label': 'Transport & Van / Coolie'},
    {'value': 'EMERGENCY_PURCHASE', 'label': 'Emergency Site Purchase'},
    {'value': 'SITE_EXPENSE', 'label': 'Site Tools & Consumables'},
    {'value': 'VENDOR_PAYMENT', 'label': 'Vendor Partial Advance'},
    {'value': 'OTHER', 'label': 'Other General Expense'},
  ];

  final List<String> _methods = const [
    'CASH',
    'BKASH',
    'NAGAD',
    'ROCKET',
    'BANK_TRANSFER',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _chargeCtrl.dispose();
    _particularCtrl.dispose();
    _voucherCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final token = UserSessionManager.instance.token ?? '';
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final charge = double.tryParse(_chargeCtrl.text.trim()) ?? 0.0;

    final result = await _api.logExpense(
      token: token,
      amount: amount,
      charge: charge,
      paidFrom: _paidFrom,
      paymentMethod: _paymentMethod,
      category: _category,
      particular: _particularCtrl.text.trim(),
      voucherNo: _voucherCtrl.text.trim(),
      leadId: _selectedProject?.id,
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (result.success) {
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to log expense'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Procurement Expense',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Paid From Switch (Company Advance vs Personal Pocket)
              const Text(
                'Paid From',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _SelectableCard(
                      label: 'Company Advance',
                      sublabel: 'Cash in Hand',
                      isSelected: _paidFrom == 'COMPANY_ADVANCE',
                      onTap: () =>
                          setState(() => _paidFrom = 'COMPANY_ADVANCE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectableCard(
                      label: 'Personal Pocket',
                      sublabel: 'Owed to Me',
                      isSelected: _paidFrom == 'PERSONAL_POCKET',
                      onTap: () =>
                          setState(() => _paidFrom = 'PERSONAL_POCKET'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Amount & Charge
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Amount (৳)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 5000',
                            prefixText: '৳ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Charge (৳)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _chargeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: '0',
                            prefixText: '৳ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Particular / Description
              const Text(
                'Particular / Description *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _particularCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 2 Rolls Masking Tape + Van rent to site',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Project Tagging
              const Text(
                'Tag Project / Client (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<ActiveProjectModel>(
                value: _selectedProject,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Select Client Project',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                items: widget.activeProjects.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${p.name} ${p.location != null ? "(${p.location})" : ""}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedProject = val),
              ),
              const SizedBox(height: 14),

              // Category and Payment Method Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _category,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem(
                              value: c['value'],
                              child: Text(
                                c['label']!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _category = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          items: _methods.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Voucher / Memo No
              const Text(
                'Voucher / Memo # (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _voucherCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Memo #1042',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _submitting
                      ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                      : const Text(
                          'Save & Submit Expense',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
