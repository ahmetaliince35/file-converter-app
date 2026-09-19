import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/theme/theme_view_model.dart';
import 'features/auth/presentation/view_models/auth_view_model.dart';
import 'services/GoogleAuthService.dart';
import 'services/microsoft_auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ChangeNotifierProvider(create: (_) => MicrosoftAuthService()),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()..load()),
        ChangeNotifierProxyProvider2<GoogleAuthService, MicrosoftAuthService, AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<GoogleAuthService>(),
            context.read<MicrosoftAuthService>(),
          ),
          update: (_, googleAuth, microsoftAuth, previous) =>
              previous ?? AuthViewModel(googleAuth, microsoftAuth),
        ),
      ],
      child: const FileConverterApp(),
    ),
  );
}
