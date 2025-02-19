import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
}

/// Clase para representar cada entrada (archivo o carpeta).
class FileEntry {
  final String name;
  final bool isDirectory;
  FileEntry({required this.name, required this.isDirectory});
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

/// Pantalla dividida en dos paneles:
/// - Izquierdo: lista de configuraciones SSH guardadas.
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

  /// Conecta vía SSH usando clave privada.
  Future<SSHClient> connectToProxmox({
    required String host,
    required int port,
    required String username,
    required String keyPath,
  }) async {
    try {
      final socket = await SSHSocket.connect(host, port);
      final keyString = await File(keyPath).readAsString();
      final privateKey = SSHKeyPair.fromPem(keyString);
      final client = SSHClient(
        socket,
        username: username,
        identities: privateKey,
      );
      print('Conexión SSH establecida con $host:$port.');
      return client;
    } catch (e) {
      print('Error al conectar a Proxmox: $e');
      rethrow;
    }
  }

  /// Carga las configuraciones guardadas desde un archivo JSON.
  Future<List<dynamic>> _loadSavedConfigs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'proxmox_config.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) return decoded;
        if (decoded is Map) return [decoded];
      } catch (e) {
        print("Error al decodificar JSON: $e");
      }
    }
    return [];
  }

  /// Guarda la configuración actual agregándola a una lista en un archivo JSON.
  Future<void> _saveConfigurationToJson() async {
    final config = {
      'host': _hostController.text,
      'port': int.parse(_portController.text),
      'username': _userController.text,
      'keyPath': _keyPathController.text,
    };

    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'proxmox_config.json'));
    List<dynamic> configs = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      try {
        final decoded = jsonDecode(content);
        if (decoded is List)
          configs = decoded;
        else if (decoded is Map) configs = [decoded];
      } catch (e) {
        configs = [];
      }
    }
    configs.add(config);
    await file.writeAsString(jsonEncode(configs));
    print('Configuración guardada en: ${file.path}');
    setState(() {});
  }

  /// Al pulsar "Conectar", se conecta y se lanza el explorador de archivos.
  Future<void> _connect() async {
    try {
      SSHClient client = await connectToProxmox(
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _userController.text,
        keyPath: _keyPathController.text,
      );

      // Guarda la configuración.
      await _saveConfigurationToJson();

      // Ejecutar "ls -p" en el directorio actual (".")
      final session = await client.execute("ls -p");
      final lsOutput =
          await session.stdout.cast<List<int>>().transform(utf8.decoder).join();
      List<String> lines =
          lsOutput.split('\n').where((line) => line.trim().isNotEmpty).toList();
      List<FileEntry> fileEntries = lines.map((line) {
        bool isDir = line.endsWith("/");
        String name = isDir ? line.substring(0, line.length - 1) : line;
        return FileEntry(name: name, isDirectory: isDir);
      }).toList();

      client.close();

      // Navegar al explorador de archivos, pasando las credenciales y el directorio inicial (".")
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FileBrowserScreen(
            host: _hostController.text,
            port: int.parse(_portController.text),
            username: _userController.text,
            keyPath: _keyPathController.text,
            initialPath: ".",
          ),
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Error de conexión"),
          content: Text("No se pudo conectar: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Aceptar"),
            ),
          ],
        ),
      );
    }
  }

  /// Panel izquierdo: lista de configuraciones guardadas.
  Widget _buildSavedConfigsPanel() {
    return FutureBuilder<List<dynamic>>(
      future: _loadSavedConfigs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return Center(
              child: Text("No hay configuraciones guardadas",
                  style: TextStyle(color: Colors.white, fontSize: 16)));
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

  /// Panel derecho: formulario de login.
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
              // Fondo dividido con CustomPainter.
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

/// CustomPainter que dibuja dos fondos para cada panel y un divisor vertical.
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

    // Línea divisoria.
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

/// Pantalla de exploración de archivos vía SSH.
/// Implementa la doble pulsación para seleccionar un elemento y, si se vuelve a pulsar,
/// navegar en el caso de las carpetas.
class FileBrowserScreen extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String keyPath;
  final String initialPath;

  const FileBrowserScreen({
    Key? key,
    required this.host,
    required this.port,
    required this.username,
    required this.keyPath,
    required this.initialPath,
  }) : super(key: key);

  @override
  _FileBrowserScreenState createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late String currentPath;
  List<FileEntry> fileList = [];
  bool loading = true;
  final double lineHeight = 36; // Alto fijo para cada línea

  // GlobalKey para obtener las coordenadas locales correctas.
  final GlobalKey _paintKey = GlobalKey();

  // Variables para controlar la posición del tap y la selección.
  Offset? _lastTapDownPosition;
  int? _selectedIndex; // índice del elemento seleccionado

  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    _listDirectory();
  }

  /// Lista el directorio actual usando "cd ... && ls -p".
  Future<void> _listDirectory() async {
    setState(() {
      loading = true;
      _selectedIndex = null; // Se limpia la selección al actualizar.
    });
    try {
      SSHClient client = await _connectSSH();
      final command = currentPath == "."
          ? "ls -p"
          : "cd '${currentPath.replaceAll("'", "\\'")}' && ls -p";
      final session = await client.execute(command);
      final lsOutput =
          await session.stdout.cast<List<int>>().transform(utf8.decoder).join();
      List<String> lines =
          lsOutput.split('\n').where((l) => l.trim().isNotEmpty).toList();

      List<FileEntry> entries = lines.map((line) {
        bool isDir = line.endsWith("/");
        String name = isDir ? line.substring(0, line.length - 1) : line;
        return FileEntry(name: name, isDirectory: isDir);
      }).toList();
      // Si no estamos en la raíz, agregamos la entrada para volver ("..")
      if (currentPath != "." && currentPath != "/") {
        entries.insert(0, FileEntry(name: "..", isDirectory: true));
      }
      client.close();
      setState(() {
        fileList = entries;
        loading = false;
      });
    } catch (e) {
      print("Error listando directorio: $e");
      setState(() {
        loading = false;
      });
    }
  }

  /// Conecta vía SSH usando las credenciales del widget.
  Future<SSHClient> _connectSSH() async {
    final socket = await SSHSocket.connect(widget.host, widget.port);
    final keyString = await File(widget.keyPath).readAsString();
    final privateKey = SSHKeyPair.fromPem(keyString);
    final client = SSHClient(
      socket,
      username: widget.username,
      identities: privateKey,
    );
    return client;
  }

  /// Maneja la doble pulsación:
  /// - Si el elemento aún no estaba seleccionado, se marca como seleccionado.
  /// - Si ya estaba seleccionado y es una carpeta (o la entrada especial ".."), se navega.
  void _handleDoubleTap() {
    if (_lastTapDownPosition == null) return;
    // Se resta el margen (20) que se usa en el painter.
    final tappedIndex = ((_lastTapDownPosition!.dy - 20) / lineHeight).floor();
    if (tappedIndex < 0 || tappedIndex >= fileList.length) return;
    final tappedEntry = fileList[tappedIndex];

    if (_selectedIndex == tappedIndex) {
      // Si ya estaba seleccionado: si es carpeta o "..", navega.
      if (tappedEntry.name == "..") {
        _goBack();
      } else if (tappedEntry.isDirectory) {
        setState(() {
          currentPath = currentPath == "."
              ? tappedEntry.name
              : p.join(currentPath, tappedEntry.name);
          _selectedIndex = null; // Limpiar la selección al navegar.
        });
        _listDirectory();
      } else {
        print("Archivo seleccionado: ${tappedEntry.name}");
      }
    } else {
      // Si aún no estaba seleccionado, se marca la selección.
      setState(() {
        _selectedIndex = tappedIndex;
      });
    }
  }

  /// Retrocede al directorio padre.
  void _goBack() {
    String parent = p.dirname(currentPath);
    if (parent == "." || parent == "/" || parent == currentPath) {
      parent = ".";
    }
    setState(() {
      currentPath = parent;
      _selectedIndex = null;
    });
    _listDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Explorador: $currentPath"),
        leading: currentPath != "." && currentPath != "/"
            ? IconButton(icon: Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : GestureDetector(
              // Utilizamos onTapDown para obtener la posición del toque
              // y convertirla a coordenadas locales del widget CustomPaint.
              onTapDown: (details) {
                final box =
                    _paintKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null) {
                  _lastTapDownPosition =
                      box.globalToLocal(details.globalPosition);
                } else {
                  _lastTapDownPosition = details.localPosition;
                }
              },
              // Se ejecuta al hacer doble clic.
              onDoubleTap: _handleDoubleTap,
              child: CustomPaint(
                key: _paintKey,
                painter: FileListPainter(
                  fileList: fileList,
                  lineHeight: lineHeight,
                  selectedIndex: _selectedIndex,
                ),
                child: Container(),
              ),
            ),
    );
  }
}

/// CustomPainter que dibuja la lista de archivos, distinguiendo carpetas y archivos,
/// e incluye la entrada especial para volver ("..").
/// Resalta el elemento seleccionado.
class FileListPainter extends CustomPainter {
  final List<FileEntry> fileList;
  final double lineHeight;
  final int? selectedIndex;
  FileListPainter({
    required this.fileList,
    required this.lineHeight,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyleFile = TextStyle(color: Colors.black87, fontSize: 16);
    final textStyleDir = TextStyle(
        color: Colors.blue.shade800, fontSize: 16, fontWeight: FontWeight.bold);
    final textStyleParent = TextStyle(
        color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    double y = 20; // margen superior

    for (int i = 0; i < fileList.length; i++) {
      final entry = fileList[i];

      // Si este elemento está seleccionado, se dibuja un fondo resaltado.
      if (selectedIndex != null && selectedIndex == i) {
        Paint highlightPaint = Paint()..color = Colors.yellow.withOpacity(0.3);
        canvas.drawRect(
            Rect.fromLTWH(0, y, size.width, lineHeight), highlightPaint);
      }

      String displayText;
      TextStyle style;
      if (entry.name == "..") {
        displayText = "⬆️ ..";
        style = textStyleParent;
      } else {
        displayText =
            entry.isDirectory ? "📁 ${entry.name}" : "📄 ${entry.name}";
        style = entry.isDirectory ? textStyleDir : textStyleFile;
      }
      textPainter.text = TextSpan(text: displayText, style: style);
      textPainter.layout(maxWidth: size.width - 20);
      textPainter.paint(canvas, Offset(10, y));
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant FileListPainter oldDelegate) {
    return oldDelegate.fileList != fileList ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
