import 'dart:ui';
import 'package:flutter/material.dart';

import '../user_profile_view_screen.dart';
import 'procurement_requisitions_screen.dart';
import 'procurement_suppliers_screen.dart';
import 'procurement_wallet_screen.dart';

class ProcurementHomeScreen extends StatefulWidget {
  const ProcurementHomeScreen({super.key});

  @override
  State<ProcurementHomeScreen> createState() => _ProcurementHomeScreenState();
}

class _ProcurementHomeScreenState extends State<ProcurementHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ProcurementRequisitionsScreen(),
    ProcurementWalletScreen(),
    ProcurementSuppliersScreen(),
    UserProfileViewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _FloatingDockItem(
                          icon: Icons.inventory_2_outlined,
                          activeIcon: Icons.inventory_2_rounded,
                          label: 'Orders',
                          isSelected: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                        ),
                        _FloatingDockItem(
                          icon: Icons.account_balance_wallet_outlined,
                          activeIcon: Icons.account_balance_wallet_rounded,
                          label: 'Wallet',
                          isSelected: _currentIndex == 1,
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                        _FloatingDockItem(
                          icon: Icons.store_mall_directory_outlined,
                          activeIcon: Icons.store_mall_directory_rounded,
                          label: 'Suppliers',
                          isSelected: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                        _FloatingDockItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: _currentIndex == 3,
                          onTap: () => setState(() => _currentIndex = 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Subtle iOS style Home Indicator Bar
              Container(
                width: 120,
                height: 3.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingDockItem extends StatelessWidget {
  const _FloatingDockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      // Selected State: Bigger active icon + Name in glowing active pill
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activeIcon,
                size: 21,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unselected State: ONLY bigger icon, NO name label
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 25,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
