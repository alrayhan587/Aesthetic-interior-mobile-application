import 'package:flutter/material.dart';

import '../data/user/user_api_service.dart';
import '../services/user_session_manager.dart';
import '../theme/crm_colors.dart';
import 'login_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  const UserProfileViewScreen({super.key});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  CurrentUser? _user;

  @override
  void initState() {
    super.initState();
    _user = UserSessionManager.instance.cachedUser;
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final token = UserSessionManager.instance.token;
    if (token == null || token.isEmpty) return;

    try {
      final fresh = await UserApiService().fetchMe(token);
      if (fresh != null && mounted) {
        setState(() => _user = fresh);
        await UserSessionManager.instance.save(fresh);
      }
    } catch (_) {}
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CrmColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserSessionManager.instance.clear();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? UserSessionManager.instance.cachedUser;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: canPop,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: CrmColors.error),
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('No active profile'))
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName.isNotEmpty ? user.fullName : 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            if (user.phone.isNotEmpty) ...[
                              _ProfileTile(
                                icon: Icons.phone_outlined,
                                title: 'Phone',
                                value: user.phone,
                              ),
                              const Divider(height: 1),
                            ],
                            _ProfileTile(
                              icon: Icons.business_outlined,
                              title: 'Departments',
                              value: user.departments.isNotEmpty
                                  ? user.departments.join(', ')
                                  : 'VISIT_TEAM',
                            ),
                            const Divider(height: 1),
                            _ProfileTile(
                              icon: Icons.verified_user_outlined,
                              title: 'Roles',
                              value: user.roles.isNotEmpty
                                  ? user.roles.join(', ')
                                  : 'Member',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleSignOut(context),
                        icon: const Icon(Icons.logout_rounded, color: CrmColors.error),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: CrmColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: CrmColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
