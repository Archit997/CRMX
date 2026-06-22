import 'package:flutter/material.dart';

import 'data/crmx_repository.dart';
import 'models/crmx_models.dart';
import 'theme/app_theme.dart';
import 'ui/auth_screen.dart';
import 'ui/home_shell.dart';

class CRMXMobileApp extends StatefulWidget {
  const CRMXMobileApp({super.key});

  @override
  State<CRMXMobileApp> createState() => _CRMXMobileAppState();
}

class _CRMXMobileAppState extends State<CRMXMobileApp> {
  final _repository = CRMXRepository();
  UserSession? _session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRMX',
      theme: AppTheme.light(),
      home: _session == null
          ? AuthScreen(
              repository: _repository,
              onSignedIn: (session) => setState(() => _session = session),
            )
          : HomeShell(
              repository: _repository,
              session: _session!,
              onLogout: () => setState(() => _session = null),
            ),
    );
  }
}
