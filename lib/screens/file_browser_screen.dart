import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/file_entry.dart';
import '../services/ssh_service.dart';
import '../widgets/blue_bar_painter.dart';
import '../widgets/file_list_painter.dart';

class FileBrowserScreen extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String keyPath;
  final String initialPath;

  const FileBrowserScreen({
    super.key,
    required this.host,
    required this.port,
    required this.username,
    required this.keyPath,
    required this.initialPath,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  late String currentPath;
  List<FileEntry> fileList = [];
  bool loading = true;
  final double lineHeight = 50;
  final GlobalKey _paintKey = GlobalKey();
  Offset? _tapPos;
  int? _selected;

  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    _listDir();
  }

  Future<SSHClient> _ssh() => SshService.connect(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        keyPath: widget.keyPath,
      );

  Future<void> _listDir() async {
    setState(() {
      loading = true;
      _selected = null;
    });
    try {
      final client = await _ssh();
      final cmd =
          currentPath == '.' ? 'ls -p' : "cd '${_esc(currentPath)}' && ls -p";
      final sess = await client.execute(cmd);
      final out =
          await sess.stdout.cast<List<int>>().transform(utf8.decoder).join();
      client.close();

      final lines = out.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final entries = lines
          .map((l) => FileEntry(
                name: l.endsWith('/') ? l.substring(0, l.length - 1) : l,
                isDirectory: l.endsWith('/'),
              ))
          .toList();
      if (currentPath != '.' && currentPath != '/') {
        entries.insert(0, const FileEntry(name: '..', isDirectory: true));
      }
      setState(() {
        fileList = entries;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _err('Error listando directorio', e);
    }
  }

  void _tap() {
    if (_tapPos == null) return;
    final idx = ((_tapPos!.dy - 20) / lineHeight).floor();
    if (idx < 0 || idx >= fileList.length) return;

    if (_selected == idx) {
      final entry = fileList[idx];
      if (entry.name == '..') {
        _back();
      } else if (entry.isDirectory) {
        setState(() {
          currentPath =
              currentPath == '.' ? entry.name : p.join(currentPath, entry.name);
          _selected = null;
        });
        _listDir();
      } else {
        _info();
      }
    } else {
      setState(() => _selected = idx);
    }
  }

  void _back() {
    final parent = p.dirname(currentPath);
    setState(() {
      currentPath = parent == '.' || parent == '/' ? '.' : parent;
      _selected = null;
    });
    _listDir();
  }

  Future<void> _info() async {
    if (_selected == null) return;
    final entry = fileList[_selected!];
    if (entry.name == '..') return;

    final path = currentPath == '.' || currentPath == '/'
        ? entry.name
        : p.join(currentPath, entry.name);

    try {
      final client = await _ssh();
      final sess = await client.execute("ls -ld '${_esc(path)}'");
      final out =
          await sess.stdout.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      _meta(entry.name, out);
    } catch (e) {
      _err('No se pudo obtener la información', e);
    }
  }

  void _meta(String name, String ls) {
    final t = ls.trim().split(RegExp(r'\s+'));
    Widget body;
    if (t.length >= 9) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Permisos', t[0]),
          _row('Usuario', t[2]),
          _row('Grupo', t[3]),
          _row('Tamaño', t[4]),
          _row('Fecha', '${t[7]} ${t[5]} ${t[6]} ${t[8]}'),
          _row('Nombre', t.sublist(9).join(' ')),
        ],
      );
    } else {
      body = Text(ls);
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Información de $name'),
        content: SingleChildScrollView(child: body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text('$k: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 16))),
        ]),
      );

  void _err(String title, Object e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        content: Text(e.toString()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'))
        ],
      ),
    );
  }

  String _esc(String text) => text.replaceAll("'", "\\'");

  bool _hasPackageJson() => fileList.any((f) => f.name == 'package.json');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explorador: $currentPath'),
        leading: currentPath != '.' && currentPath != '/'
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
            : null,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Stack(children: [
                GestureDetector(
                  onTapDown: (d) {
                    final box = _paintKey.currentContext?.findRenderObject()
                        as RenderBox?;
                    _tapPos =
                        box?.globalToLocal(d.globalPosition) ?? d.localPosition;
                  },
                  onTap: _tap,
                  child: CustomPaint(
                    key: _paintKey,
                    painter: FileListPainter(
                      fileList: fileList,
                      lineHeight: lineHeight,
                      selectedIndex: _selected,
                    ),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 20 + fileList.length * lineHeight,
                    ),
                  ),
                ),
                if (_selected != null &&
                    _selected! < fileList.length &&
                    fileList[_selected!].name != '..')
                  Positioned(
                    right: 10,
                    top: 20 + _selected! * lineHeight,
                    child: IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: Colors.blue, size: 24),
                      onPressed: _info,
                    ),
                  ),
              ]),
            ),
      bottomNavigationBar: _hasPackageJson()
          ? SizedBox(
              height: 50,
              child: CustomPaint(
                painter: BlueBarPainter(
                  connected: true, // TODO: sustituir con estado real
                  port: 20217,
                ),
              ),
            )
          : null,
    );
  }
}
