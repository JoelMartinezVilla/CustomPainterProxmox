import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

class SshService {
  const SshService._();

  static Future<SSHClient> connect({
    required String host,
    required int port,
    required String username,
    required String keyPath,
  }) async {
    final socket = await SSHSocket.connect(host, port);
    final keyString = await File(keyPath).readAsString();
    final privateKey = SSHKeyPair.fromPem(keyString);
    return SSHClient(
      socket,
      username: username,
      identities: privateKey,
    );
  }
}
