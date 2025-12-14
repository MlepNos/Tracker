import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isRegister = false;
  String? error;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();

    return Scaffold(
      appBar: AppBar(title: Text(isRegister ? "Register" : "Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        if (isRegister) {
                          await auth.register(emailCtrl.text.trim(), passCtrl.text);
                        } else {
                          await auth.login(emailCtrl.text.trim(), passCtrl.text);
                        }
                      } catch (e) {
                        setState(() => error = e.toString());
                      } finally {
                        setState(() => loading = false);
                      }
                    },
              child: Text(loading ? "Please wait..." : (isRegister ? "Register" : "Login")),
            ),
            TextButton(
              onPressed: () => setState(() {
                isRegister = !isRegister;
                error = null;
              }),
              child: Text(isRegister ? "Have an account? Login" : "No account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
