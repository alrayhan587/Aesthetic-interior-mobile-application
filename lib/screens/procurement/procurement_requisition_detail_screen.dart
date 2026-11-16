import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

import '../../data/procurement/procurement_api_service.dart';
import '../../data/procurement/procurement_models.dart';
import '../../services/user_session_manager.dart';

enum RequisitionTradeScope {
  all,
  cabinets,
  wallPaneling,
  hardware,
  ceiling,
  others,
}

class ProcurementRequisitionDetailScreen extends StatefulWidget {
  const ProcurementRequisitionDetailScreen({
    super.key,
    required this.requisitionId,
  });

  final String requisitionId;

  @override
  State<ProcurementRequisitionDetailScreen> createState() =>
      _ProcurementRequisitionDetailScreenState();
}

class _ProcurementRequisitionDetailScreenState
    extends State<ProcurementRequisitionDetailScreen> {
  final ProcurementApiService _api = ProcurementApiService();
  final TextEditingController _itemSearchCtrl = TextEditingController();

  MaterialRequisitionDetail? _requisition;
  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;
  String? _error;

  RequisitionTradeScope _selectedScope = RequisitionTradeScope.all;
  bool _showPendingOnly = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
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
      final res =
          await _api.fetchRequisitionDetail(token, widget.requisitionId);
      if (mounted) {
        if (res != null) {
          setState(() {
            _requisition = res.requisition;
            _suppliers = res.suppliers;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load requisition details';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading details';
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final token = UserSessionManager.instance.token ?? '';
    if (token.isEmpty) return;

    final success = await _api.updateRequisitionStatus(
      token,
      widget.requisitionId,
      newStatus,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Requisition marked as $newStatus'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadDetail();
    }
  }

  void _openPurchaseSheet(MaterialRequisitionItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PurchaseLoggerSheet(
        item: item,
        suppliers: _suppliers,
        requisitionId: widget.requisitionId,
        onSuccess: () {
          Navigator.of(context).pop();
          _loadDetail();
        },
      ),
    );
  }

  // ── Trade Scope Classifier ────────────────────────────────────────────────
  RequisitionTradeScope _classifyTrade(MaterialRequisitionItemModel item) {
    final cat = item.workCategory.toUpperCase();
    final name = item.materialName.toLowerCase();
    final spec = (item.specifications ?? '').toLowerCase();

    // Wall Paneling
    if (cat.contains('WALL') ||
        cat.contains('PANEL') ||
        name.contains('wall') ||
        name.contains('decorative panel') ||
        name.contains('fluted') ||
        name.contains('charcoal') ||
        name.contains('accent') ||
        name.contains('t bit') ||
        name.contains('t-bit') ||
        name.contains('profile')) {
      return RequisitionTradeScope.wallPaneling;
    }

    // Cabinets & Closets
    if (cat.contains('CABINET') ||
        cat.contains('CLOSET') ||
        name.contains('cabinet') ||
        name.contains('closet')) {
      return RequisitionTradeScope.cabinets;
    }

    // Hardware
    if (cat.contains('HARDWARE') ||
        cat.contains('SCREW') ||
        cat.contains('FASTENER') ||
        name.contains('hardware') ||
        name.contains('screw') ||
        name.contains('nail') ||
        name.contains('pin') ||
        name.contains('anchor') ||
        name.contains('adhesive') ||
        name.contains('solvent') ||
        name.contains('gum') ||
        name.contains('glue') ||
        name.contains('hinge')) {
      return RequisitionTradeScope.hardware;
    }

    // Ceiling
    if (cat.contains('CEILING') ||
        name.contains('ceiling') ||
        name.contains('gypsum')) {
      return RequisitionTradeScope.ceiling;
    }

    // Boards classification
    if (name.contains('board') || name.contains('plywood')) {
      if (spec.contains('cabinet') || spec.contains('closet')) {
        return RequisitionTradeScope.cabinets;
      }
      return RequisitionTradeScope.wallPaneling;
    }

    return RequisitionTradeScope.others;
  }

  // Filtered List based on scope, search, and pending toggle
  List<MaterialRequisitionItemModel> get _filteredItems {
    if (_requisition == null) return [];
    var list = _requisition!.items;

    // Filter by Scope
    if (_selectedScope != RequisitionTradeScope.all) {
      list = list.where((i) => _classifyTrade(i) == _selectedScope).toList();
    }

    // Filter by Pending Only
    if (_showPendingOnly) {
      list = list.where((i) => !i.isBought).toList();
    }

    // Filter by Search Query
    final query = _itemSearchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((i) {
        final mName = i.materialName.toLowerCase();
        final spec = (i.specifications ?? '').toLowerCase();
        final cat = i.workCategory.toLowerCase();
        return mName.contains(query) ||
            spec.contains(query) ||
            cat.contains(query);
      }).toList();
    }

    return list;
  }

  // ── Scope Metrics Counters ────────────────────────────────────────────────
  ({int total, int billed}) _getScopeCounts(RequisitionTradeScope scope) {
    if (_requisition == null) return (total: 0, billed: 0);
    final items = scope == RequisitionTradeScope.all
        ? _requisition!.items
        : _requisition!.items.where((i) => _classifyTrade(i) == scope).toList();
    final billed = items.where((i) => i.isBought).length;
    return (total: items.length, billed: billed);
  }

  @override
  Widget build(BuildContext context) {
    final req = _requisition;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  req?.requisitionNo ?? 'Requisition',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (req != null) ...[
                  const SizedBox(width: 6),
                  _buildHeaderStatusPill(req.status),
                ],
              ],
            ),
            if (req != null)
              Text(
                req.lead.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadDetail,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFoldingCube(
          color: Color(0xFF2563EB),
          size: 34.0,
        ),
      );
    }

    if (_error != null || _requisition == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 30,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _error ?? 'Failed to load requisition',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final req = _requisition!;
    final totalCount = req.items.length;
    final billedCount = req.billedItemsCount;
    final pendingCount = totalCount - billedCount;
    final progress = totalCount > 0 ? (billedCount / totalCount) : 0.0;
    final itemsToDisplay = _filteredItems;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // ── 1. Client info & Requisition summary (SCROLLS AWAY WITH SCROLL) ─
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildClientSummaryCard(req, progress),
          ),
        ),

        // ── 2. STICKY HEADER: Stat Tag + Search + Filters (STUCK ON SCROLL) ─
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickySearchAndFilterDelegate(
            height: 126,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live Stat Progress Strip
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$billedCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: ' of $totalCount items billed',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 65,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 65 * progress,
                                decoration: BoxDecoration(
                                  color: progress == 1.0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pendingCount left',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: pendingCount == 0
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Search Field + "Pending Only" Toggle
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _itemSearchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search items, thickness, specs...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 17,
                              color: Color(0xFF94A3B8),
                            ),
                            suffixIcon: _itemSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 15),
                                    onPressed: () {
                                      _itemSearchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // "Pending" Filter Toggle
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showPendingOnly = !_showPendingOnly;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _showPendingOnly
                              ? const Color(0xFFD97706)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _showPendingOnly
                                  ? const Color(0xFFD97706).withValues(alpha: 0.25)
                                  : const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showPendingOnly
                                  ? Icons.filter_alt_rounded
                                  : Icons.filter_alt_outlined,
                              size: 14,
                              color: _showPendingOnly
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _showPendingOnly
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Smart Category Filter Pills (Horizontal SingleChildScrollView to avoid scroll conflicts)
                SizedBox(
                  height: 34,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildScopePill(
                          scope: RequisitionTradeScope.all,
                          label: 'All',
                        ),
                        const SizedBox(width: 6),
                        _buildScopePill(
                          scope: RequisitionTradeScope.cabinets,
                          label: 'Cabinets',
                        ),
                        const SizedBox(width: 6),
                        _buildScopePill(
                          scope: RequisitionTradeScope.wallPaneling,
                          label: 'Wall Paneling',
                        ),
                        const SizedBox(width: 6),
                        _buildScopePill(
                          scope: RequisitionTradeScope.hardware,
                          label: 'Hardware',
                        ),
                        if (_getScopeCounts(RequisitionTradeScope.ceiling).total > 0) ...[
                          const SizedBox(width: 6),
                          _buildScopePill(
                            scope: RequisitionTradeScope.ceiling,
                            label: 'Ceiling',
                          ),
                        ],
                        if (_getScopeCounts(RequisitionTradeScope.others).total > 0) ...[
                          const SizedBox(width: 6),
                          _buildScopePill(
                            scope: RequisitionTradeScope.others,
                            label: 'Others',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 3. Redesigned Material Items List ───────────────────────────────
        if (itemsToDisplay.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 26,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showPendingOnly
                          ? 'All items in this scope are billed!'
                          : 'No items match your filter.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (_showPendingOnly) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _showPendingOnly = false),
                        child: const Text('Show All Items'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = itemsToDisplay[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RedesignedExecutiveMaterialCard(
                      index: index + 1,
                      item: item,
                      onTap: () => _openPurchaseSheet(item),
                    ),
                  );
                },
                childCount: itemsToDisplay.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Client Summary Card (Scrolls away) ───────────────────────────────────
  Widget _buildClientSummaryCard(
    MaterialRequisitionDetail req,
    double progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.lead.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (req.lead.location != null &&
                        req.lead.location!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              req.lead.location!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: progress == 1.0
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}% Done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: progress == 1.0
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),

          // Status Action Buttons
          if (req.status == 'SUBMITTED') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('IN_PROCUREMENT'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'Start Sourcing & Billing',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else if (req.status == 'IN_PROCUREMENT' && progress == 1.0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('FULFILLED'),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Mark All Sourced & Fulfilled',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Smart Filter Pill ─────────────────────────────────────────────────────
  Widget _buildScopePill({
    required RequisitionTradeScope scope,
    required String label,
  }) {
    final counts = _getScopeCounts(scope);
    final isSelected = _selectedScope == scope;
    final isFullyBilled = counts.total > 0 && counts.billed == counts.total;

    return InkWell(
      onTap: () => setState(() => _selectedScope = scope),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF0F172A).withValues(alpha: 0.22)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: isSelected ? 6 : 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : isFullyBilled
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${counts.billed}/${counts.total}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : isFullyBilled
                          ? const Color(0xFF059669)
                          : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'FULFILLED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Completed';
        break;
      case 'IN_PROCUREMENT':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'In Sourcing';
        break;
      case 'SUBMITTED':
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Awaiting';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Search & Filter Header Delegate (Crash-Proof, Pinned, Never Overflows)
// ─────────────────────────────────────────────────────────────────────────────
class _StickySearchAndFilterDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _StickySearchAndFilterDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: Material(
        color: const Color(0xFFF8FAFC),
        elevation: shrinkOffset > 0 ? 3 : 0,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchAndFilterDelegate oldDelegate) {
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Executive Material Card
// - Rich procurement information
// - Full comprehensive heading
// - Prominent thickness badge
// - Wastage & Net breakdown
// - Full card color reflects status (Pending: White, Billed: Soft Green)
// - Whole card clickable (no button needed)
// ─────────────────────────────────────────────────────────────────────────────
class _RedesignedExecutiveMaterialCard extends StatelessWidget {
  const _RedesignedExecutiveMaterialCard({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final MaterialRequisitionItemModel item;
  final VoidCallback onTap;

  // Build full descriptive material heading
  String _buildFullHeading(MaterialRequisitionItemModel item) {
    final rawName = item.materialName.trim();
    final rawSpec = (item.specifications ?? '').trim();

    final cleanSpec = rawSpec.replaceAll(RegExp(r'\s*\+\s*'), ' ').trim();
    final cleanName = rawName.replaceAll(RegExp(r'\s*\+\s*'), ' ').trim();

    if (cleanSpec.isEmpty) return cleanName;

    final lowerName = cleanName.toLowerCase();
    if (lowerName == 'boards' ||
        lowerName.contains('closet boards') ||
        lowerName.contains('cabinet / closet boards')) {
      return cleanSpec;
    }

    if (cleanSpec.toLowerCase().contains(lowerName)) {
      return cleanSpec;
    }

    if (lowerName.contains('screw') &&
        cleanSpec.toLowerCase().contains('screw')) {
      return cleanSpec;
    }
    if (lowerName.contains('nail') &&
        cleanSpec.toLowerCase().contains('nail')) {
      return cleanSpec;
    }

    return '$cleanName  $cleanSpec';
  }

  // Extract ONLY thickness (e.g. 18mm, 12mm, 6mm, 0.75", 35mm)
  String? _extractThickness(MaterialRequisitionItemModel item) {
    final combined = '${item.specifications ?? ''} ${item.materialName}';
    final match = RegExp(
      r'(\d+(\.\d+)?\s*(mm|inch|"|in)(\s*\([^)]+\))?)',
      caseSensitive: false,
    ).firstMatch(combined);

    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  // Category Icon & Color
  ({String label, IconData icon, Color color}) _getCategoryVisuals(String cat) {
    final c = cat.toUpperCase();
    if (c.contains('CABINET') || c.contains('CLOSET')) {
      return (
        label: 'Cabinet & Closet',
        icon: Icons.kitchen_rounded,
        color: const Color(0xFF2563EB),
      );
    }
    if (c.contains('WALL') || c.contains('PANEL')) {
      return (
        label: 'Wall Paneling',
        icon: Icons.view_quilt_rounded,
        color: const Color(0xFF7C3AED),
      );
    }
    if (c.contains('HARDWARE') || c.contains('SCREW') || c.contains('NAIL')) {
      return (
        label: 'Hardware & Fittings',
        icon: Icons.build_circle_rounded,
        color: const Color(0xFFD97706),
      );
    }
    if (c.contains('CEILING')) {
      return (
        label: 'Ceiling Scope',
        icon: Icons.roofing_rounded,
        color: const Color(0xFF0D9488),
      );
    }
    return (
      label: 'Material Scope',
      icon: Icons.category_rounded,
      color: const Color(0xFF64748B),
    );
  }

  static String _cleanNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isBought = item.isBought;
    final purchase = item.purchaseRecord;
    final fullHeading = _buildFullHeading(item);
    final thickness = _extractThickness(item);
    final categoryMeta = _getCategoryVisuals(item.workCategory);

    // Wastage & Net information
    final hasWastage = item.wastagePercent > 0;
    final hasNetDiff = item.netQuantity > 0 && item.netQuantity != item.finalQuantity;

    // Background color:
    // - Pending: White
    // - Billed: Soft Green
    final Color cardBg = isBought
        ? const Color(0xFFF0FDF4)
        : Colors.white;

    final Color shadowColor = isBought
        ? const Color(0xFF059669).withValues(alpha: 0.08)
        : const Color(0xFF0F172A).withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Bar: Category Pill + Sequence # + Status Pill ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Trade Category Pill
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: categoryMeta.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            categoryMeta.icon,
                            size: 13,
                            color: categoryMeta.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          categoryMeta.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: categoryMeta.color,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${index.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    // Status Pill
                    if (isBought)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 11,
                              color: Color(0xFF15803D),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Billed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PulseDot(color: Color(0xFFF59E0B), size: 5),
                            SizedBox(width: 4),
                            Text(
                              'Pending Billing',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 2. Full Descriptive Material Heading ────────────────────
                Text(
                  fullHeading,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // ── 3. Specs Row: Thickness Badge + Quantity + Wastage ──────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Thickness Pill & Wastage Note
                    Row(
                      children: [
                        if (thickness != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBought
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.straighten_rounded,
                                  size: 11.5,
                                  color: isBought
                                      ? const Color(0xFF166534)
                                      : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  thickness,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isBought
                                        ? const Color(0xFF166534)
                                        : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasWastage || hasNetDiff) ...[
                          const SizedBox(width: 8),
                          Text(
                            hasWastage
                                ? '+${item.wastagePercent.toInt()}% waste'
                                : 'Net: ${_cleanNumber(item.netQuantity)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Right: High-Contrast Quantity Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: isBought
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${_cleanNumber(item.finalQuantity)} ',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isBought
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                            TextSpan(
                              text: item.unit,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isBought
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 4. Interactive Bottom Section: Billing Info or Tap Hint ─
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isBought
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  child: isBought && purchase != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Supplier & Rate
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.storefront_rounded,
                                        size: 13,
                                        color: Color(0xFF15803D),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          purchase.supplierName ?? 'Billed Vendor',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Rate: ৳${_cleanNumber(purchase.unitRate)}/${item.unit} • Qty: ${_cleanNumber(purchase.purchasedQty)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Total Cost & Edit Hint
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '৳ ${NumberFormat('#,##0').format(purchase.totalCost)}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    const Text(
                                      'Tap to edit',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 13,
                                  color: Color(0xFF2563EB),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tap card to log purchase & billing',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Live Indicator Dot
// ─────────────────────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 6.0});
  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _animation = Tween<double>(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Purchase Logger Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PurchaseLoggerSheet extends StatefulWidget {
  const _PurchaseLoggerSheet({
    required this.item,
    required this.suppliers,
    required this.requisitionId,
    required this.onSuccess,
  });

  final MaterialRequisitionItemModel item;
  final List<SupplierModel> suppliers;
  final String requisitionId;
  final VoidCallback onSuccess;

  @override
  State<_PurchaseLoggerSheet> createState() => _PurchaseLoggerSheetState();
}

class _PurchaseLoggerSheetState extends State<_PurchaseLoggerSheet> {
  final ProcurementApiService _api = ProcurementApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _rateCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _notesCtrl;

  SupplierModel? _selectedSupplier;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.item.purchaseRecord;
    _rateCtrl = TextEditingController(
      text: p != null && p.unitRate > 0 ? p.unitRate.toString() : '',
    );
    _qtyCtrl = TextEditingController(
      text: (p?.purchasedQty ?? widget.item.finalQuantity).toString(),
    );
    _notesCtrl = TextEditingController(text: p?.notes ?? '');

    if (p?.supplierId != null) {
      _selectedSupplier = widget.suppliers.firstWhere(
        (s) => s.id == p!.supplierId,
        orElse: () => widget.suppliers.first,
      );
    }
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final token = UserSessionManager.instance.token ?? '';
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final qty =
        double.tryParse(_qtyCtrl.text.trim()) ?? widget.item.finalQuantity;

    final success = await _api.logItemPurchase(
      token: token,
      requisitionId: widget.requisitionId,
      itemId: widget.item.id,
      supplierId: _selectedSupplier?.id,
      supplierName: _selectedSupplier?.displayName,
      unitRate: rate,
      purchasedQty: qty,
      notes: _notesCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (success) {
        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record purchase')),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Record Item Purchase',
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
            const SizedBox(height: 6),
            Text(
              widget.item.materialName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
            const Divider(height: 20),

            // Supplier Selector
            const Text(
              'Supplier / Vendor',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<SupplierModel>(
              value: _selectedSupplier,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select Supplier',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              items: widget.suppliers.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSupplier = val),
            ),
            const SizedBox(height: 14),

            // Rate and Quantity Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unit Rate (৳ / ${widget.item.unit})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 1500',
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Purchased Qty (${widget.item.unit})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 10',
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
              ],
            ),
            const SizedBox(height: 14),

            // Notes
            const Text(
              'Remarks / Delivery Notes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Picked from Mirpur branch with challan',
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
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _submitting
                    ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                    : const Text(
                        'Save Purchase Record',
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
    );
  }
}
