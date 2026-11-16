import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

import '../../data/procurement/procurement_api_service.dart';
import '../../data/procurement/procurement_models.dart';
import '../../services/notification_manager.dart';
import '../../services/user_session_manager.dart';
import '../../widgets/notifications/notification_bottom_sheet.dart';
import '../user_profile_view_screen.dart';
import 'procurement_requisition_detail_screen.dart';
import 'procurement_wallet_screen.dart';

enum _SortOption {
  newest,
  oldest,
  mostItems,
  highestProgress,
}

class ProcurementRequisitionsScreen extends StatefulWidget {
  const ProcurementRequisitionsScreen({super.key});

  @override
  State<ProcurementRequisitionsScreen> createState() =>
      _ProcurementRequisitionsScreenState();
}

class _ProcurementRequisitionsScreenState
    extends State<ProcurementRequisitionsScreen> {
  final ProcurementApiService _api = ProcurementApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _statusFilter = 'ALL';
  _SortOption _sortOption = _SortOption.newest;
  List<MaterialRequisitionSummary> _requisitions = [];
  ProcurementDashboardData? _dashboardData;
  ProcurementWalletData? _walletData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
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
      final results = await Future.wait([
        _api.fetchRequisitions(
          token,
          status: _statusFilter,
          search: _searchCtrl.text.trim(),
        ),
        _api.fetchDashboard(token),
        _api.fetchWallet(token),
      ]);

      if (mounted) {
        setState(() {
          _requisitions = results[0] as List<MaterialRequisitionSummary>;
          _dashboardData = results[1] as ProcurementDashboardData?;
          _walletData = results[2] as ProcurementWalletData?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load requisitions';
        });
      }
    }
  }

  void _onFilterChanged(String newStatus) {
    if (_statusFilter == newStatus) return;
    setState(() => _statusFilter = newStatus);
    _loadAllData();
  }

  List<MaterialRequisitionSummary> get _sortedRequisitions {
    final list = List<MaterialRequisitionSummary>.from(_requisitions);
    switch (_sortOption) {
      case _SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortOption.mostItems:
        list.sort((a, b) => b.totalItems.compareTo(a.totalItems));
        break;
      case _SortOption.highestProgress:
        list.sort((a, b) {
          final progA = a.totalItems > 0 ? a.billedItems / a.totalItems : 0.0;
          final progB = b.totalItems > 0 ? b.billedItems / b.totalItems : 0.0;
          return progB.compareTo(progA);
        });
        break;
    }
    return list;
  }

  void _showSortFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sort & Filter Requisitions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _sortOption = _SortOption.newest;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Reset', style: TextStyle(color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSortTile(
                title: 'Newest First',
                option: _SortOption.newest,
                icon: Icons.calendar_today_rounded,
              ),
              _buildSortTile(
                title: 'Oldest First',
                option: _SortOption.oldest,
                icon: Icons.history_rounded,
              ),
              _buildSortTile(
                title: 'Highest Progress',
                option: _SortOption.highestProgress,
                icon: Icons.trending_up_rounded,
              ),
              _buildSortTile(
                title: 'Most Items Count',
                option: _SortOption.mostItems,
                icon: Icons.format_list_numbered_rounded,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile({
    required String title,
    required _SortOption option,
    required IconData icon,
  }) {
    final isSelected = _sortOption == option;
    return InkWell(
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF2563EB),
              ),
          ],
        ),
      ),
    );
  }

  // ── Metrics Calculation ──────────────────────────────────────────────────
  double get _procurementBalance {
    if (_walletData != null) {
      return _walletData!.wallet.advanceBalance;
    }
    if (_dashboardData != null) {
      return _dashboardData!.wallet.advanceBalance;
    }
    return 0.0;
  }

  int get _activeCount {
    if (_dashboardData != null) {
      return _dashboardData!.metrics.totalRequisitions;
    }
    return _requisitions.length;
  }

  int get _inSourcingCount {
    if (_dashboardData != null) {
      return _dashboardData!.metrics.inProcurementCount;
    }
    return _requisitions.where((r) => r.isInProcurement).length;
  }

  int get _awaitingCount {
    if (_dashboardData != null) {
      return _dashboardData!.metrics.submittedCount;
    }
    return _requisitions.where((r) => r.isSubmitted).length;
  }

  int get _completedCount {
    if (_dashboardData != null) {
      return _dashboardData!.metrics.fulfilledCount;
    }
    return _requisitions.where((r) => r.isCompleted).length;
  }

  @override
  Widget build(BuildContext context) {
    final cachedUser = UserSessionManager.instance.cachedUser;
    final userName = cachedUser?.fullName ?? 'Procurement Officer';
    final userInitial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'P';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient soft glow in top right corner
          Positioned(
            top: -100,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.08),
                      const Color(0xFFF59E0B).withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 0.85],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Executive Top Navigation Header ──────────────────────
                _buildExecutiveTopHeader(userInitial),

                // ── Scrollable Body with Controls & Cards ────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAllData,
                    color: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        // Search & Filter Controls (Mini KPI Strip removed)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                _buildSearchBarAndFilterButton(),
                                const SizedBox(height: 12),
                                _buildFilterPillsRow(),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),

                        // Card List or State View
                        _buildListSliver(),

                        // Padding for bottom floating dock
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 90),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Executive Top Header (Just Logo + Balance Pill + Notification + Avatar) ──
  Widget _buildExecutiveTopHeader(String userInitial) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Just Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
            ),
          ),

          // Right: Procurement Balance Pill + Notification Bell + User Avatar
          Row(
            children: [
              // Procurement Balance Pill (Single Line with extended width for 7+ digits)
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProcurementWalletScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 13.5,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 7),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 135),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '৳ ${NumberFormat('#,##0').format(_procurementBalance)}',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Notification Bell with Badge (No border, shadow outside)
              ListenableBuilder(
                listenable: NotificationManager.instance,
                builder: (context, _) {
                  final unread = NotificationManager.instance.unreadCount;
                  return InkWell(
                    onTap: () => NotificationBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                            color: Color(0xFF334155),
                          ),
                          if (unread > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF43F5E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Executive Avatar Pill
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserProfileViewScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF334155)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    userInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Bigger Search Field & Filter Button with Outside Shadow, No Border ──
  Widget _buildSearchBarAndFilterButton() {
    return Row(
      children: [
        // Search Input (Bigger, height 48, with outside shadow, no border)
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _loadAllData(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'Search by REQ # or client...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: const Color(0xFF94A3B8),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadAllData();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Filter / Sort Action Button (Outside shadow, no border)
        InkWell(
          onTap: _showSortFilterModal,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 20,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Smart Filter Pills with Counters ───────────────────────────────────
  Widget _buildFilterPillsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _SmartFilterPill(
            label: 'All',
            count: _activeCount,
            isSelected: _statusFilter == 'ALL',
            onTap: () => _onFilterChanged('ALL'),
            selectedBgColor: const Color(0xFF0F172A),
            selectedFgColor: Colors.white,
          ),
          const SizedBox(width: 8),
          _SmartFilterPill(
            label: 'In Sourcing',
            count: _inSourcingCount,
            isSelected: _statusFilter == 'IN_PROCUREMENT',
            showDot: true,
            dotColor: const Color(0xFF2563EB),
            onTap: () => _onFilterChanged('IN_PROCUREMENT'),
            selectedBgColor: const Color(0xFF2563EB),
            selectedFgColor: Colors.white,
            inactiveBgColor: const Color(0xFFEFF6FF),
            inactiveTextColor: const Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 8),
          _SmartFilterPill(
            label: 'Awaiting',
            count: _awaitingCount,
            isSelected: _statusFilter == 'SUBMITTED',
            onTap: () => _onFilterChanged('SUBMITTED'),
            selectedBgColor: const Color(0xFFD97706),
            selectedFgColor: Colors.white,
          ),
          const SizedBox(width: 8),
          _SmartFilterPill(
            label: 'Completed',
            count: _completedCount,
            isSelected: _statusFilter == 'FULFILLED',
            onTap: () => _onFilterChanged('FULFILLED'),
            selectedBgColor: const Color(0xFF059669),
            selectedFgColor: Colors.white,
          ),
        ],
      ),
    );
  }

  // ── 4. Requisitions List / State Views ────────────────────────────────────
  Widget _buildListSliver() {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: SpinKitFoldingCube(
            color: Color(0xFF2563EB),
            size: 34.0,
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
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
                  _error!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadAllData,
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
        ),
      );
    }

    final displayList = _sortedRequisitions;

    if (displayList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Requisitions Found',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchCtrl.text.isNotEmpty
                      ? 'No items matched "${_searchCtrl.text.trim()}". Try another term.'
                      : _statusFilter == 'ALL'
                          ? 'No material requisitions have been logged yet.'
                          : 'No requisitions currently match this status filter.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final req = displayList[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _LuxuryRequisitionCard(
                index: index,
                item: req,
                onTap: () async {
                  final refreshed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ProcurementRequisitionDetailScreen(
                        requisitionId: req.id,
                      ),
                    ),
                  );
                  if (refreshed == true && mounted) {
                    _loadAllData();
                  }
                },
              ),
            );
          },
          childCount: displayList.length,
        ),
      ),
    );
  }
}

// ── Smart Filter Pill with Count Badge ──────────────────────────────────────
class _SmartFilterPill extends StatelessWidget {
  const _SmartFilterPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.selectedBgColor,
    required this.selectedFgColor,
    this.inactiveBgColor,
    this.inactiveTextColor,
    this.showDot = false,
    this.dotColor,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedBgColor;
  final Color selectedFgColor;
  final Color? inactiveBgColor;
  final Color? inactiveTextColor;
  final bool showDot;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? selectedBgColor
        : (inactiveBgColor ?? Colors.white);
    final textColor = isSelected
        ? selectedFgColor
        : (inactiveTextColor ?? const Color(0xFF475569));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? selectedBgColor.withValues(alpha: 0.25)
                  : const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot && dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing Live Status Dot ─────────────────────────────────────────────────
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

// ── Luxury Requisition Card (No Border, Outside Shadow) ──────────────────────
class _LuxuryRequisitionCard extends StatelessWidget {
  const _LuxuryRequisitionCard({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final MaterialRequisitionSummary item;
  final VoidCallback onTap;

  // Extract smart initials (e.g. "Mr Abdus Samad Nirob" -> "ASN")
  String _extractInitials(String name) {
    final clean = name
        .replaceAll(
          RegExp(r'^(Mr\.|Mrs\.|Ms\.|Dr\.|Engr\.)\s*', caseSensitive: false),
          '',
        )
        .trim();
    final parts =
        clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'PR';
    if (parts.length == 1) {
      return parts[0]
          .substring(0, math.min(2, parts[0].length))
          .toUpperCase();
    }
    if (parts.length >= 3) {
      return '${parts[0][0]}${parts[1][0]}${parts[2][0]}'.toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Generate color pair for client avatar badge
  ({LinearGradient gradient, Color text}) _getAvatarColors(int idx) {
    final palettes = [
      (
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        text: const Color(0xFF1D4ED8),
      ),
      (
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFEDD5)],
        ),
        text: const Color(0xFFC2410C),
      ),
      (
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECFDF5), Color(0xFFCCFBF1)],
        ),
        text: const Color(0xFF0F766E),
      ),
      (
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF5FF), Color(0xFFEDE9FE)],
        ),
        text: const Color(0xFF6D28D9),
      ),
    ];
    return palettes[idx % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final progress = item.totalItems > 0
        ? (item.billedItems / item.totalItems).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = progress * 100;
    final avatarStyle = _getAvatarColors(index);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // No border! Rich exterior shadow:
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Badge & Status Pill ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // REQ Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            item.requisitionNo,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              letterSpacing: 0.4,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Pill
                    _buildStatusPill(item.status),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Client Section with Avatar Badge & Location ─────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Initials Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: avatarStyle.gradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _extractInitials(item.lead.name),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: avatarStyle.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Client Name & Location Chip
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.lead.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          if (item.lead.location != null &&
                              item.lead.location!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      item.lead.location!.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Redesigned Progress Section: Dual Tone Container ────
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Sourcing Progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: progress > 0
                                      ? const Color(0xFFDBEAFE)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${progressPercent.toStringAsFixed(progressPercent == 0 || progressPercent == 100 ? 0 : 1)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: progress > 0
                                        ? const Color(0xFF1D4ED8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${item.billedItems} ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                TextSpan(
                                  text: '/ ${item.totalItems} items',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // Gradient Progress Track
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 7,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 7,
                                width: constraints.maxWidth * progress,
                                decoration: BoxDecoration(
                                  gradient: item.isCompleted
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF2563EB),
                                            Color(0xFF3B82F6),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: progress > 0
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF2563EB)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Card Footer Meta & Quick Action ─────────────────────
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Prepared By
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'By ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                TextSpan(
                                  text: item.createdBy,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Date & Manage Button
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Manage',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    if (status == 'FULFILLED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
            SizedBox(width: 5),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'IN_PROCUREMENT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseDot(color: Color(0xFF2563EB), size: 6),
            SizedBox(width: 5),
            Text(
              'In Sourcing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      );
    }

    // Default / SUBMITTED
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: Color(0xFFF59E0B), size: 6),
          SizedBox(width: 5),
          Text(
            'Awaiting',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}
