import 'package:flutter/material.dart';

class WidgetTreeView extends StatelessWidget {
  const WidgetTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'CrmMobileApp (StatelessWidget)',
      '  └─ MaterialApp',
      '      ├─ AnnotatedRegion<SystemUiOverlayStyle>',
      '      └─ home: AppRoot',
      '          ├─ LoggedIn -> RootScreen',
      '          └─ LoggedOut -> LoginScreen',
      '',
      'RootScreen (StatefulWidget)',
      '  ├─ Loading: Scaffold > Center > SpinKitFoldingCube',
      '  ├─ SeniorCrmHomeScreen',
      '  │   ├─ Scaffold',
      '  │   ├─ body: AnimatedSwitcher -> Dashboard / Queue / Budget / Profile',
      '  │   └─ bottomNavigationBar: NavigationBar',
      '  ├─ VisitTeamHomeScreen',
      '  │   ├─ Scaffold',
      '  │   ├─ body: AnimatedSwitcher -> Dashboard / Visits / TodayVisits / Profile/Control',
      '  │   └─ bottomNavigationBar: NavigationBar',
      '  └─ Access Denied: Scaffold > Column > [Icon, Text, Button]',
      '',
      'LoginScreen (StatefulWidget)',
      '  ├─ Scaffold > Stack',
      '  ├─ WireframeBackground',
      '  └─ SafeArea > Center > Card > Form [Email, Password, Sign In Button]',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Widget Tree')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
      ),
    );
  }
}
