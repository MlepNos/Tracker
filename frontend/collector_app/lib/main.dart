import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'auth_state.dart';
import 'token_store.dart';

import 'pages/login_page.dart';
import 'pages/collections_page.dart';
import 'theme/steam_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  final tokenStore = TokenStore(storage);
  final api = ApiClient(tokenStore: tokenStore);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: tokenStore),
        ChangeNotifierProvider(
          create: (_) => AuthState(api: api, tokenStore: tokenStore)..loadFromStorage(),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collector',
      theme: steamTheme(),
      home: Consumer<AuthState>(
        builder: (_, auth, __) {
          return auth.isLoggedIn ? const CollectionsPage() : const LoginPage();
        },
      ),
    );
  }
}
