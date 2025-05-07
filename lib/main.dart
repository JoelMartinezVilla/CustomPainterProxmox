import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const ProxmoxManagerApp());
}

class ProxmoxManagerApp extends StatelessWidget {
  const ProxmoxManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor Proxmox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
