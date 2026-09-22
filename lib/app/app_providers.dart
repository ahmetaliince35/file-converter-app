import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/theme/theme_view_model.dart';
import '../features/auth/data/google_auth_service.dart';
import '../features/auth/data/microsoft_auth_service.dart';
import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/home/presentation/view_models/home_view_model.dart';

List<SingleChildWidget> buildAppProviders() => [
      ChangeNotifierProvider(create: (_) => GoogleAuthService()),
      ChangeNotifierProvider(create: (_) => MicrosoftAuthService()),
      ChangeNotifierProvider(create: (_) => ThemeViewModel()..load()),
      ChangeNotifierProxyProvider2<GoogleAuthService, MicrosoftAuthService,
          AuthViewModel>(
        create: (context) => AuthViewModel(
          context.read<GoogleAuthService>(),
          context.read<MicrosoftAuthService>(),
        ),
        update: (_, googleAuth, microsoftAuth, previous) =>
            previous ?? AuthViewModel(googleAuth, microsoftAuth),
      ),
      ChangeNotifierProxyProvider2<GoogleAuthService, MicrosoftAuthService,
          HomeViewModel>(
        create: (context) => HomeViewModel(
          context.read<GoogleAuthService>(),
          context.read<MicrosoftAuthService>(),
        ),
        update: (_, googleAuth, microsoftAuth, previous) =>
            previous ?? HomeViewModel(googleAuth, microsoftAuth),
      ),
    ];
