import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/shared_file.dart';
import 'encryption_service.dart';

class FileServer {
  HttpServer? _server;
  String? _serverIP;
  final int _port = 8080;
  
  final Map<String, SharedFile> _sharedFiles = {};
  
  bool _isHotspotMode = false;

  Future<String?> startServer({bool isHotspotMode = false}) async {
    try {
      _isHotspotMode = isHotspotMode;
      
      if (isHotspotMode) {
        _serverIP = '192.168.43.1';
      } else {
        _serverIP = await _getLocalIP();
      }
      
      final router = Router();

      router.post('/api/upload', _handleUpload);
      router.get('/api/file/<code>', _getFileInfo);
      router.post('/api/download/<code>', _downloadFile);

      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_corsHeaders())
          .addHandler(router);

      _server = await shelf_io.serve(
        handler, 
        InternetAddress.anyIPv4, 
        _port,
      );
      
      print('🚀 Server: http://$_serverIP:$_port (Hotspot: $isHotspotMode)');
      return 'http://$_serverIP:$_port';
      
    } catch (e) {
      print('❌ Server error: $e');
      return null;
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _sharedFiles.clear();
    print('⛔ Server stopped');
  }

  Middleware _corsHeaders() {
    return createMiddleware(
      requestHandler: (Request request) {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _getCorsHeaders());
        }
        return null;
      },
      responseHandler: (Response response) {
        return response.change(headers: _getCorsHeaders());
      },
    );
  }

  Map<String, String> _getCorsHeaders() => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            if (!addr.address.startsWith('169.254')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('IP error: $e');
    }
    return '127.0.0.1';
  }

  Future<Response> _handleUpload(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      
      final code = const Uuid().v4().substring(0, 6).toUpperCase();
      
      DateTime? expiryTime;
      if (data['expiryMinutes'] != null) {
        final minutes = int.parse(data['expiryMinutes'].toString());
        expiryTime = DateTime.now().add(Duration(minutes: minutes));
      }

      String? hashedPassword;
      if (data['password'] != null && data['password'].toString().isNotEmpty) {
        hashedPassword = EncryptionService.hashPassword(data['password']);
      }

      int? maxDownloads;
      if (data['maxDownloads'] != null) {
        maxDownloads = int.parse(data['maxDownloads'].toString());
      }

      _sharedFiles[code] = SharedFile(
        code: code,
        filename: data['filename'],
        filePath: data['filePath'],
        size: int.parse(data['size'].toString()),
        password: hashedPassword,
        maxDownloads: maxDownloads,
        expiryTime: expiryTime,
      );

      return Response.ok(jsonEncode({
        'success': true,
        'code': code,
        'url': 'http://$_serverIP:$_port/d/$code'
      }));
      
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()})
      );
    }
  }

  Response _getFileInfo(Request request, String code) {
    final file = _sharedFiles[code];
    
    if (file == null) {
      return Response.notFound(
        jsonEncode({'error': 'File not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (file.isExpired) {
      _sharedFiles.remove(code);
      return Response(410, 
        body: jsonEncode({'error': 'File expired'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (file.hasReachedLimit) {
      return Response(410, 
        body: jsonEncode({'error': 'Download limit reached'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(jsonEncode({
      'filename': file.filename,
      'size': file.size,
      'requiresPassword': file.isPasswordProtected,
      'downloads': file.downloads,
      'maxDownloads': file.maxDownloads,
      'expiryTime': file.expiryTime?.toIso8601String(),
    }), headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _downloadFile(Request request, String code) async {
    final file = _sharedFiles[code];
    
    if (file == null) {
      return Response.notFound(
        jsonEncode({'error': 'File not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (file.isExpired) {
      _sharedFiles.remove(code);
      return Response(410,
        body: jsonEncode({'error': 'File expired'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (file.hasReachedLimit) {
      return Response(410,
        body: jsonEncode({'error': 'Download limit reached'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (file.isPasswordProtected) {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final providedPassword = data['password']?.toString() ?? '';
        
        if (!EncryptionService.verifyPassword(providedPassword, file.password!)) {
          return Response(403,
            body: jsonEncode({'error': 'Wrong password'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        return Response(403,
          body: jsonEncode({'error': 'Password required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    try {
      final fileData = await File(file.filePath).readAsBytes();
      
      file.downloads++;

      return Response.ok(
        fileData,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="${file.filename}"',
          'Content-Length': fileData.length.toString(),
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to read file: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String? shareFile(File file, {String? password, int? maxDownloads, int? expiryMinutes}) {
    final code = const Uuid().v4().substring(0, 6).toUpperCase();
    
    DateTime? expiryTime;
    if (expiryMinutes != null) {
      expiryTime = DateTime.now().add(Duration(minutes: expiryMinutes));
    }

    String? hashedPassword;
    if (password != null && password.isNotEmpty) {
      hashedPassword = EncryptionService.hashPassword(password);
    }

    _sharedFiles[code] = SharedFile(
      code: code,
      filename: file.path.split('/').last,
      filePath: file.path,
      size: file.lengthSync(),
      password: hashedPassword,
      maxDownloads: maxDownloads,
      expiryTime: expiryTime,
    );

    return code;
  }

  SharedFile? getFile(String code) => _sharedFiles[code];

  String? get serverUrl => _serverIP != null ? 'http://$_serverIP:$_port' : null;
  bool get isHotspotMode => _isHotspotMode;
}