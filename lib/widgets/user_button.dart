import 'package:flutter/material.dart';

import '../screens/user_profile_view_screen.dart';
import '../services/user_session_manager.dart';

/// Renders user avatar and opens profile view on tap.
class UserButton extends StatelessWidget {
  const UserButton({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final user = UserSessionManager.instance.cachedUser;
    if (user == null) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const UserProfileViewScreen(),
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.person_rounded,
            size: size * 0.55,
            color: Colors.grey.shade700,
          ),
        ),
      );
    }

    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const UserProfileViewScreen(),
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.44,
          ),
        ),
      ),
    );
  }
}
