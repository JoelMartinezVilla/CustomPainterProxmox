import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

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

/// Pantalla que dibuja el fondo y los bordes con CustomPainter,
/// y posiciona TextFields para editar directamente.
class CustomFormScreen extends StatefulWidget {
  @override
  _CustomFormScreenState createState() => _CustomFormScreenState();
}

class _CustomFormScreenState extends State<CustomFormScreen> {
  // Controladores para cada campo de entrada.
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '22');
  final TextEditingController _userController = TextEditingController();
  // Ahora este campo se usará para la ruta de la clave privada.
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

  /// Función que se invoca al pulsar el botón "Conectar".
  Future<void> _connect() async {
    try {
      SSHClient client = await connectToProxmox(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _userController.text,
        keyPath: _keyPathController.text, // Ruta de la clave privada
      );

      // Mostrar diálogo de conexión exitosa.
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

      // Una vez realizada la operación, cierra la conexión.
      client.close();
    } catch (e) {
      // Mostrar error en caso de fallo.
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

  @override
  Widget build(BuildContext context) {
    // Usamos LayoutBuilder para calcular posiciones y dimensiones.
    return Scaffold(
      appBar: AppBar(
        title: Text("Conectar a Proxmox"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double screenWidth = constraints.maxWidth;
          // Definimos márgenes y dimensiones de los campos:
          double startX = 50;
          double fieldWidth = screenWidth - 100; // 50 de margen en cada lado
          double fieldHeight = 60; // Se deja más espacio para el valor
          double startY = 200;
          double spacing = 15; // Espacio entre campos

          return Stack(
            children: [
              // Fondo y bordes dibujados con CustomPainter.
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: FormPainter(),
              ),
              // Campo "Host".
              Positioned(
                left: startX,
                top: startY,
                width: fieldWidth,
                height: fieldHeight,
                child: TextField(
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
              ),
              // Campo "Puerto".
              Positioned(
                left: startX,
                top: startY + fieldHeight + spacing,
                width: fieldWidth,
                height: fieldHeight,
                child: TextField(
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
              ),
              // Campo "Usuario".
              Positioned(
                left: startX,
                top: startY + 2 * (fieldHeight + spacing),
                width: fieldWidth,
                height: fieldHeight,
                child: TextField(
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
              ),
              // Campo "Ruta clave privada".
              Positioned(
                left: startX,
                top: startY + 3 * (fieldHeight + spacing),
                width: fieldWidth,
                height: fieldHeight,
                child: TextField(
                  controller: _keyPathController,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Ruta clave privada (.ssh/id_rsa)",
                    hintStyle: TextStyle(color: Colors.white70),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  ),
                ),
              ),
              // Botón "Conectar".
              Positioned(
                left: startX,
                top: startY + 4 * (fieldHeight + spacing),
                width: fieldWidth,
                height: fieldHeight,
                child: ElevatedButton(
                  onPressed: _connect,
                  style: ElevatedButton.styleFrom(
                    // primary: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text("Conectar", style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// CustomPainter que dibuja el fondo degradado y los bordes de los campos.
/// Para el botón, dibuja un borde redondeado.
class FormPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fondo degradado.
    Rect rect = Offset.zero & size;
    Paint bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blueAccent, Colors.lightBlueAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Parámetros de diseño (deben coincidir con los Positioned).
    double startX = 50;
    double startY = 200;
    double fieldWidth = size.width - 100;
    double fieldHeight = 60;
    double spacing = 15;

    Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dibujar bordes para cada campo (Host, Puerto, Usuario, Ruta clave privada).
    for (int i = 0; i < 4; i++) {
      double top = startY + i * (fieldHeight + spacing);
      Rect fieldRect = Rect.fromLTWH(startX, top, fieldWidth, fieldHeight);
      canvas.drawRect(fieldRect, borderPaint);
    }

    // Para el botón, en lugar de un rectángulo normal, dibujamos un borde redondeado.
    double buttonTop = startY + 4 * (fieldHeight + spacing);
    Rect buttonRect = Rect.fromLTWH(startX, buttonTop, fieldWidth, fieldHeight);
    RRect buttonRRect =
        RRect.fromRectAndRadius(buttonRect, Radius.circular(30));
    canvas.drawRRect(buttonRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
