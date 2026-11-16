import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../data/procurement/procurement_api_service.dart';
import '../../data/procurement/procurement_models.dart';
import '../../services/user_session_manager.dart';
import '../../widgets/mobile_app_header.dart';

class ProcurementSuppliersScreen extends StatefulWidget {
  const ProcurementSuppliersScreen({super.key});

  @override
  State<ProcurementSuppliersScreen> createState() =>
      _ProcurementSuppliersScreenState();
}

class _ProcurementSuppliersScreenState
    extends State<ProcurementSuppliersScreen> {
  final ProcurementApiService _api = ProcurementApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'ALL';

  final List<String> _categories = const [
    'ALL',
    'Board',
    'Hardware',
    'Glass',
    'Paint',
    'Electrical',
  ];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
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
      final list = await _api.fetchSuppliers(
        token,
        category: _selectedCategory,
        search: _searchCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _suppliers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load suppliers';
        });
      }
    }
  }

  void _onCategoryChanged(String cat) {
    if (_selectedCategory == cat) return;
    setState(() => _selectedCategory = cat);
    _loadSuppliers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: MobileAppHeader(
        title: 'Supplier Directory',
        onRefresh: _loadSuppliers,
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _loadSuppliers(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search supplier or shop name...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadSuppliers();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) {
                      final isSelected = _selectedCategory == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _onCategoryChanged(c),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c == 'ALL' ? 'All Vendors' : c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── List of Suppliers ────────────────────────────────────
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
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

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSuppliers,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_suppliers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(Icons.storefront_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Suppliers Found',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No registered vendors match this criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuppliers,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _suppliers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = _suppliers[index];
          return _SupplierCard(supplier: s);
        },
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier});

  final SupplierModel supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code and Category
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                supplier.supplierCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF2563EB),
                ),
              ),
              if (supplier.supplyCategory != null &&
                  supplier.supplyCategory!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    supplier.supplyCategory!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Contact Person Name
          Text(
            supplier.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),

          // Company / Shop Name
          if (supplier.companyName != null &&
              supplier.companyName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              supplier.companyName!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],

          // Address
          if (supplier.address != null && supplier.address!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    supplier.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),

          // Phone and Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (supplier.phone != null && supplier.phone!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 6),
                    Text(
                      supplier.phone!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No phone listed',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),

              // Action Buttons
              if (supplier.phone != null && supplier.phone!.isNotEmpty)
                Row(
                  children: [
                    // Copy Phone
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Number',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: supplier.phone!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${supplier.phone!}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
