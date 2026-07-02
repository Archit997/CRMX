import 'package:flutter/material.dart';

import 'data/crmx_repository.dart';
import 'theme/app_theme.dart';
import 'ui/client_list_screen.dart';

class CRMXMobileApp extends StatelessWidget {
  const CRMXMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRMX',
      theme: AppTheme.light(),
      home: ClientListScreen(repository: CRMXRepository()),
    );
  }
}
