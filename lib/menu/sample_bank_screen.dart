import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class SampleBankScreen extends StatefulWidget {
  @override
  _SampleBankScreenState createState() => _SampleBankScreenState();
}

class _SampleBankScreenState extends State<SampleBankScreen> {
  final Dio _dio = Dio();
  bool _isDownloading = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      _showProgressNotification('İndirme başlatılıyor...');

      final response = await _dio.post('http://192.168.1.103:5000/api/download/generate');
      final downloadUrl = response.data['downloadUrl'] as String;

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status != PermissionStatus.granted) {
          _showErrorNotification('Depolama izni reddedildi');
          return;
        }
      }

      final Directory dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final String filePath = "${dir.path}/test.mp3";

      await _dio.download(downloadUrl, filePath);

      _showSuccessNotification('İndirme Tamamlandı!', filePath);

    } catch (e) {
      _showErrorNotification('İndirme hatası: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showProgressNotification(String message) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.download, color: Colors.white),
          SizedBox(width: 8),
          Text(message),
        ]),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(days: 1), // SnackBar sürekli kalacak
      ),
    );
  }

  void _showSuccessNotification(String message, String filePath) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 8),
          Text(message),
        ]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'AÇ',
          textColor: Colors.white,
          onPressed: () => _openFile(filePath),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showErrorNotification(String message) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger == null) return;

    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.error, color: Colors.white),
          SizedBox(width: 8),
          Flexible(child: Text(message)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      _showErrorNotification('Dosya açılamadı: Uygun uygulama yükleyin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text('Sample Bank')),
        body: Center(
          child: ElevatedButton(
            onPressed: _isDownloading ? null : _downloadFile,
            child: _isDownloading
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 8),
                Text('İndiriliyor...'),
              ],
            )
                : Text('Dosyayı İndir'),
          ),
        ),
      ),
    );
  }
}
