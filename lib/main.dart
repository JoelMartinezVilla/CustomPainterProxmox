import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(MyApp());
}

/// Widget principal de la aplicación.
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor Proxmox',
      debugShowCheckedModeBanner: false,
      home: CustomFormScreen(),
    );
  }
}

/// Pantalla que se divide en dos paneles:
/// - Izquierdo: lista de SSH guardados en el archivo JSON.
/// - Derecho: formulario de login para conectarse vía SSH.
class CustomFormScreen extends StatefulWidget {
  @override
  _CustomFormScreenState createState() => _CustomFormScreenState();
}

class _CustomFormScreenState extends State<CustomFormScreen> {
  // Controladores para el formulario de login.
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '22');
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _keyPathController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _keyPathController.dispose();
    super.dispose();
  }

  /// Función que establece la conexión SSH con Proxmox usando una clave privada.
  Future<SSHClient> connectToProxmox({
    required String host,
    required int port,
    required String username,
    required String keyPath,
  }) async {
    try {
      // Conectar al host en el puerto indicado.
      final socket = await SSHSocket.connect(host, port);
      // Leer el contenido del archivo de clave privada.
      final keyString = await File(keyPath).readAsString();
      // Convertir el contenido PEM en un objeto SSHPrivateKey usando el método actualizado.
      final privateKey = SSHKeyPair.fromPem(keyString);
      // Crear el cliente SSH utilizando la clave privada.
      final client = SSHClient(
        socket,
        username: username,
        identities: privateKey,
      );
      print('Conexión SSH establecida con $host:$port usando clave privada.');
      return client;
    } catch (e) {
      print('Error al conectar a Proxmox: $e');
      rethrow;
    }
  }

  /// Carga las configuraciones guardadas desde el archivo JSON.
  Future<List<dynamic>> _loadSavedConfigs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'proxmox_config.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map) {
          return [decoded];
        }
      } catch (e) {
        print("Error al decodificar JSON: $e");
      }
    }
    return [];
  }

  /// Guarda la configuración actual en un archivo JSON.
  /// Se agrega la configuración al final de una lista.
  Future<void> _saveConfigurationToJson() async {
    final config = {
      'host': _hostController.text,
      'port': int.parse(_portController.text),
      'username': _userController.text,
      'keyPath': _keyPathController.text,
    };

    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, 'proxmox_config.json'));
    List<dynamic> configs = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) {
          configs = decoded;
        } else if (decoded is Map) {
          configs = [decoded];
        }
      } catch (e) {
        configs = [];
      }
    }
    configs.add(config);
    await file.writeAsString(jsonEncode(configs));
    print('Configuración guardada en: ${file.path}');
    // Actualizamos la UI para mostrar la nueva configuración
    setState(() {});
  }

  /// Función que se invoca al pulsar el botón "Conectar".
  Future<void> _connect() async {
    try {
      SSHClient client = await connectToProxmox(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _userController.text,
        keyPath: _keyPathController.text,
      );

      // Guarda la configuración en el JSON (se acumulan todas las conexiones)
      await _saveConfigurationToJson();

      // Muestra diálogo de conexión exitosa.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Conexión exitosa"),
          content: Text(
              "Conectado a ${_hostController.text}:${_portController.text}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Aceptar"),
            ),
          ],
        ),
      );
      // Cierra la conexión cuando ya no se necesite.
      client.close();
    } catch (e) {
      // Muestra error en caso de fallo.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Error de conexión"),
          content: Text("No se pudo conectar: $e"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Aceptar"),
            ),
          ],
        ),
      );
    }
  }

  /// Panel izquierdo: muestra la lista de configuraciones SSH guardadas.
  Widget _buildSavedConfigsPanel() {
    return FutureBuilder<List<dynamic>>(
      future: _loadSavedConfigs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text("No hay configuraciones guardadas",
                  style: TextStyle(color: Colors.white, fontSize: 16)));
        }
        final configs = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final config = configs[index];
            return Card(
              color: Colors.white.withOpacity(0.8),
              child: ListTile(
                title: Text(
                  "${config['host']} : ${config['port']}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Usuario: ${config['username']}"),
                onTap: () {
                  // Al tocar, se rellenan los campos del login con la configuración seleccionada.
                  setState(() {
                    _hostController.text = config['host'];
                    _portController.text = config['port'].toString();
                    _userController.text = config['username'];
                    _keyPathController.text = config['keyPath'];
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Panel derecho: formulario de login para conectarse vía SSH.
  Widget _buildLoginPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _hostController,
              style: TextStyle(fontSize: 18, color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Host",
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _portController,
              style: TextStyle(fontSize: 18, color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Puerto",
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _userController,
              style: TextStyle(fontSize: 18, color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Usuario",
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _keyPathController,
              style: TextStyle(fontSize: 18, color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Ruta clave privada (ej. ~/.ssh/id_rsa)",
                hintStyle: TextStyle(color: Colors.white70),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              ),
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                // primary: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text("Conectar", style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestor Proxmox"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double height = constraints.maxHeight;
          double leftWidth = width * 0.5;
          double rightWidth = width - leftWidth;

          return Stack(
            children: [
              // CustomPainter que dibuja el fondo de cada panel y el divisor.
              CustomPaint(
                size: Size(width, height),
                painter: SplitScreenPainter(),
              ),
              // Panel izquierdo: configuraciones guardadas.
              Positioned(
                left: 0,
                top: 0,
                width: leftWidth,
                height: height,
                child: _buildSavedConfigsPanel(),
              ),
              // Panel derecho: formulario de login.
              Positioned(
                left: leftWidth,
                top: 0,
                width: rightWidth,
                height: height,
                child: _buildLoginPanel(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// CustomPainter que dibuja dos fondos distintos para cada panel y un divisor vertical.
class SplitScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fondo panel izquierdo.
    Rect leftRect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    Paint leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomLeft,
      ).createShader(leftRect);
    canvas.drawRect(leftRect, leftPaint);

    // Fondo panel derecho.
    Rect rightRect =
        Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    Paint rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        begin: Alignment.topRight,
        end: Alignment.bottomRight,
      ).createShader(rightRect);
    canvas.drawRect(rightRect, rightPaint);

    // Línea divisoria vertical.
    Paint dividerPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      dividerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
