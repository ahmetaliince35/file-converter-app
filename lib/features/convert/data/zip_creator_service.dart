import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import '../../../../core/files/temp_file_manager.dart';

typedef ZipProgressCallback = void Function(
    double progress,
    String currentFile,
    int processedBytes,
    int totalBytes,
    );

class ZipCreatorService {
  static Future<File> createZipFromFiles(
      List<File> files, {
        ZipProgressCallback? onProgress,
      }) async {
    if (files.isEmpty) throw Exception('Arşivlenecek dosya bulunamadı.');

    final workingDir = await TempFileManager.workingDir;
    final zipFileName = 'Arsiv_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFilePath = '${workingDir.path}/$zipFileName';

    int totalBytes = 0;
    final validPaths = <String>[];
    for (final f in files) {
      if (f.existsSync()) {
        validPaths.add(f.path);
        totalBytes += f.lengthSync();
      }
    }
    if (totalBytes == 0) totalBytes = 1;

    final receivePort = ReceivePort();
    final completer = Completer<void>();

    final isolate = await Isolate.spawn(_zipWorker, {
      'sendPort': receivePort.sendPort,
      'inputPaths': validPaths,
      'outputPath': zipFilePath,
      'totalBytes': totalBytes,
    });

    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'progress') {
          onProgress?.call(
            message['progress'] as double,
            message['currentFile'] as String,
            message['processedBytes'] as int,
            message['totalBytes'] as int,
          );
        } else if (type == 'done') {
          completer.complete();
        } else if (type == 'error') {
          completer.completeError(Exception(message['error']));
        }
      }
    });

    try {
      await completer.future;
    } finally {
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }

    return File(zipFilePath);
  }

  static Future<void> _zipWorker(Map<String, dynamic> args) async {
    final sendPort = args['sendPort'] as SendPort;
    final inputPaths = args['inputPaths'] as List<String>;
    final outputPath = args['outputPath'] as String;
    final totalBytes = args['totalBytes'] as int;

    try {
      final outputFile = File(outputPath);
      final outputStream = OutputFileStream(outputFile.path);
      final zipEncoder = ZipEncoder();

      zipEncoder.startEncode(outputStream);

      int totalConsumedBytes = 0;

      for (int i = 0; i < inputPaths.length; i++) {
        final path = inputPaths[i];
        final file = File(path);
        if (!file.existsSync()) continue;

        final fileName = file.uri.pathSegments.last;
        final fileSize = file.lengthSync();

        // Küçük dosyalarda hızlı ekleme
        if (fileSize < 10 * 1024 * 1024) {
          final inputStream = InputFileStream(path);
          final archiveFile = ArchiveFile.stream(fileName, fileSize, inputStream);
          zipEncoder.addFile(archiveFile);
          inputStream.close();

          totalConsumedBytes += fileSize;
        } else {
          // BÜYÜK DOSYALAR VE VİDEOLAR İÇİN ASENKRON CHUNK AKIŞI
          // Dosyayı parça parça okuyup her adımda ana thread'e yüzde bildiriyoruz
          final fileStream = file.openRead();
          final bytesBuilder = BytesBuilder(copy: false);

          await for (final chunk in fileStream) {
            bytesBuilder.add(chunk);
            totalConsumedBytes += chunk.length;

            final currentProgress = (totalConsumedBytes / totalBytes).clamp(0.01, 0.99);
            final processedMB = (totalConsumedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

            // Her chunk okunduğunda anlık olarak UI'a progress fırlatıyoruz (Kilitlenme yok!)
            sendPort.send({
              'type': 'progress',
              'progress': currentProgress,
              'currentFile': '$fileName ($processedMB / $totalMB MB)',
              'processedBytes': totalConsumedBytes,
              'totalBytes': totalBytes,
            });
          }

          final archiveFile = ArchiveFile(fileName, fileSize, bytesBuilder.takeBytes());
          archiveFile.compress = false; // Video/Büyük dosyalarda CPU'yu yormamak için STORE modu
          zipEncoder.addFile(archiveFile);
        }

        // Dosya bittiğinde garanti yüzde
        sendPort.send({
          'type': 'progress',
          'progress': (totalConsumedBytes / totalBytes).clamp(0.01, 0.99),
          'currentFile': fileName,
          'processedBytes': totalConsumedBytes,
          'totalBytes': totalBytes,
        });
      }

      zipEncoder.endEncode();
      outputStream.close();

      sendPort.send({
        'type': 'progress',
        'progress': 1.0,
        'currentFile': 'Tamamlandı',
        'processedBytes': totalBytes,
        'totalBytes': totalBytes,
      });

      sendPort.send({'type': 'done'});
    } catch (e) {
      sendPort.send({'type': 'error', 'error': e.toString()});
    }
  }
}