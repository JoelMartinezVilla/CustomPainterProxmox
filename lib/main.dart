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
  /// Si la configuración ya existe, no se añade de nuevo.
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
    // Verificamos si la configuración ya existe.
    bool exists = configs.any((c) =>
        c['host'] == config['host'] &&
        c['port'] == config['port'] &&
        c['username'] == config['username'] &&
        c['keyPath'] == config['keyPath']);
    if (!exists) {
      configs.add(config);
      await file.writeAsString(jsonEncode(configs));
      print('Configuración guardada en: ${file.path}');
    } else {
      print('La configuración ya existe, no se añade.');
    }
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

      // Guarda la configuración (si no existe).
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
  // Altura de cada línea para facilitar el clic.
  final double lineHeight = 50;

  // GlobalKey para obtener las coordenadas locales correctas.
  final GlobalKey _paintKey = GlobalKey();

  // Variable para controlar la posición del tap y la selección.
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

  /// Maneja el clic único:
  /// - Si se toca un elemento por primera vez, se selecciona.
  /// - Si se toca de nuevo el mismo elemento (ya seleccionado):
  ///    • Si es "..", retrocede.
  ///    • Si es una carpeta, se navega.
  ///    • Si es un archivo, se muestra la información.
  void _handleTap() {
    if (_lastTapDownPosition == null) return;
    final tappedIndex = ((_lastTapDownPosition!.dy - 20) / lineHeight).floor();
    if (tappedIndex < 0 || tappedIndex >= fileList.length) return;
    final tappedEntry = fileList[tappedIndex];

    if (_selectedIndex == tappedIndex) {
      // Si ya estaba seleccionado, se abre la carpeta o se muestra info si es archivo.
      if (tappedEntry.name == "..") {
        _goBack();
      } else if (tappedEntry.isDirectory) {
        setState(() {
          currentPath = currentPath == "."
              ? tappedEntry.name
              : p.join(currentPath, tappedEntry.name);
          _selectedIndex = null;
        });
        _listDirectory();
      } else {
        _showFileInfo();
      }
    } else {
      // Si no estaba seleccionado, solo se marca la selección.
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

  /// Muestra la información (metadata y permisos) del archivo o carpeta seleccionado.
  Future<void> _showFileInfo() async {
    if (_selectedIndex == null || _selectedIndex! >= fileList.length) return;
    FileEntry entry = fileList[_selectedIndex!];
    if (entry.name == "..")
      return; // No se muestra info para la entrada de retroceso.
    String filePath;
    if (currentPath == "." || currentPath == "/") {
      filePath = entry.name;
    } else {
      filePath = p.join(currentPath, entry.name);
    }

    try {
      SSHClient client = await _connectSSH();
      // Se utiliza "ls -ld" para obtener la metadata y permisos.
      String command = "ls -ld '${filePath.replaceAll("'", "\\'")}'";
      final session = await client.execute(command);
      String result =
          await session.stdout.cast<List<int>>().transform(utf8.decoder).join();
      client.close();

      // Se intenta parsear el resultado en tokens.
      List<String> tokens = result.trim().split(RegExp(r'\s+'));
      Widget contentWidget;
      if (tokens.length >= 9) {
        String permissions = tokens[0];
        String owner = tokens[2];
        String group = tokens[3];
        String size = tokens[4];
        String date = "${tokens[7]} ${tokens[5]} ${tokens[6]} ${tokens[8]}";
        String name = tokens.sublist(9).join(" ");

        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Permisos:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(permissions, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Usuario:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(owner, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Grupo:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(group, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Tamaño:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(size, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Fecha:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(date, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Nombre:",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(name, style: TextStyle(fontSize: 16)),
          ],
        );
      } else {
        contentWidget = Text(result);
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text("Información de ${entry.name}"),
          content: SingleChildScrollView(child: contentWidget),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cerrar"),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text("Error"),
          content: Text("No se pudo obtener la información: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cerrar"),
            ),
          ],
        ),
      );
    }
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
          : SingleChildScrollView(
              child: Stack(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      final box = _paintKey.currentContext?.findRenderObject()
                          as RenderBox?;
                      if (box != null) {
                        _lastTapDownPosition =
                            box.globalToLocal(details.globalPosition);
                      } else {
                        _lastTapDownPosition = details.localPosition;
                      }
                    },
                    onTap: _handleTap,
                    child: CustomPaint(
                      key: _paintKey,
                      painter: FileListPainter(
                        fileList: fileList,
                        lineHeight: lineHeight,
                        selectedIndex: _selectedIndex,
                      ),
                      // Se usa un SizedBox para definir la altura total de la lista:
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 20 +
                            fileList.length *
                                lineHeight, // 20 es el margen superior
                      ),
                    ),
                  ),
                  if (_selectedIndex != null &&
                      _selectedIndex! < fileList.length &&
                      fileList[_selectedIndex!].name != "..")
                    Positioned(
                        right: 10,
                        top: 20 + _selectedIndex! * lineHeight,
                        child: IconButton(
                          icon: Icon(Icons.info_outline,
                              color: Colors.blue, size: 24),
                          onPressed: _showFileInfo,
                        )),
                  // Positioned(
                  //     right: 40,
                  //     top: 20 + _selectedIndex! * lineHeight,
                  //     child: IconButton(
                  //       icon: Icon(Icons.edit, color: Colors.grey, size: 24),
                  //       onPressed: _renameSelected,
                  //     ))
                ],
              ),
            ),
      bottomNavigationBar: containsPackageJson(fileList)
          ? SizedBox(
              height: 50,
              child: CustomPaint(
                painter: BlueBarPainter(
                    connected: /*AQUI EN VEZ DE TRUE TIENE QUE IR EL BOOLEANO QUE COMPRUEBA SI EL SERVER SE ENCIENDE BIEN*/
                        true,
                    port: 20217),
                child: Container(),
              ),
            )
          : null,
    );
  }
}

/// CustomPainter que dibuja la lista de archivos, distinguiendo carpetas y archivos,
/// e incluye la entrada especial para volver (".."). Se resalta el elemento seleccionado.
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

      // Si el elemento está seleccionado, se dibuja un fondo resaltado.
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

bool containsPackageJson(List<FileEntry> fileList) {
  return fileList.any((file) => file.name == "package.json");
}

class BlueBarPainter extends CustomPainter {
  final bool connected;
  final int? port;

  BlueBarPainter({required this.connected, this.port});

  @override
  void paint(Canvas canvas, Size size) {
    // Pintura para la barra azul
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Dibuja el rectángulo azul que ocupa toda la barra
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);

    // Pintura para el círculo de estado
    final circlePaint = Paint()
      ..color = connected ? Colors.green : Colors.red
      ..style = PaintingStyle.fill;

    final circleRadius = size.height * 0.25;
    final circleCenter = Offset(size.height * 0.5, size.height * 0.5);

    // Dibuja el círculo
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);

    // Definir el texto según el estado
    final String text = connected
        ? "Servidor NodeJS funcionant al port ${port}"
        : "ERROR: El servidor NodeJS no esta funcionant";

    // Configuración del texto
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.3, // Ajusta el tamaño del texto
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(minWidth: 0, maxWidth: size.width);

    // Posición centrada del texto en la barra
    final textX = (size.width - textPainter.width) / 2;
    final textY = (size.height - textPainter.height) / 2;

    // Dibuja el texto
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant BlueBarPainter oldDelegate) {
    return oldDelegate.connected != connected;
  }
}
