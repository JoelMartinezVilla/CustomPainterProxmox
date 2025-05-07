import 'package:flutter/material.dart';
import '../services/ssh_service.dart';
import '../utils/json_storage.dart';
import '../widgets/split_screen_painter.dart';
import 'file_browser_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController();
  final _keyPathCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _keyPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await SshService.connect(
        host: _hostCtrl.text,
        port: int.parse(_portCtrl.text),
        username: _userCtrl.text,
        keyPath: _keyPathCtrl.text,
      );

      await JsonStorage.saveConfig({
        'host': _hostCtrl.text,
        'port': int.parse(_portCtrl.text),
        'username': _userCtrl.text,
        'keyPath': _keyPathCtrl.text,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FileBrowserScreen(
            host: _hostCtrl.text,
            port: int.parse(_portCtrl.text),
            username: _userCtrl.text,
            keyPath: _keyPathCtrl.text,
            initialPath: '.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error de conexión'),
          content: Text('No se pudo conectar: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  Widget _savedConfigs() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: JsonStorage.loadConfigs(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final configs = snapshot.data!;
        if (configs.isEmpty) {
          return const Center(
            child: Text(
              'No hay configuraciones guardadas',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: configs.length,
          itemBuilder: (_, i) {
            final c = configs[i];
            return Card(
              color: Colors.white.withOpacity(0.8),
              child: ListTile(
                title: Text(
                  '${c['host']} : ${c['port']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Usuario: ${c['username']}'),
                onTap: () => setState(() {
                  _hostCtrl.text = c['host'];
                  _portCtrl.text = c['port'].toString();
                  _userCtrl.text = c['username'];
                  _keyPathCtrl.text = c['keyPath'];
                }),
              ),
            );
          },
        );
      },
    );
  }

  Widget _loginForm() {
    InputDecoration _dec(String hint) => InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _hostCtrl, decoration: _dec('Host')),
            const SizedBox(height: 15),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Puerto'),
            ),
            const SizedBox(height: 15),
            TextField(controller: _userCtrl, decoration: _dec('Usuario')),
            const SizedBox(height: 15),
            TextField(
              controller: _keyPathCtrl,
              decoration: _dec('Ruta clave privada'),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Conectar', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor Proxmox')),
      body: LayoutBuilder(
        builder: (_, c) {
          final left = c.maxWidth * 0.5;
          return Stack(
            children: [
              CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: SplitScreenPainter(),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: left,
                height: c.maxHeight,
                child: _savedConfigs(),
              ),
              Positioned(
                left: left,
                top: 0,
                width: c.maxWidth - left,
                height: c.maxHeight,
                child: _loginForm(),
              ),
            ],
          );
        },
      ),
    );
  }
}
