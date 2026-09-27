import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/files/temp_file_manager.dart';

class MicrosoftGraphService {
  final String accessToken;

  MicrosoftGraphService(this.accessToken);

  Future<File> convertOfficeToPdf(File inputFile) async {
    final fileName = inputFile.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final tempUploadName = 'temp_${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final uploadUrl = Uri.parse(
      'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName:/content',
    );

    // Stream ile dosya yüklemek için StreamedRequest kullanılır:
    final uploadRequest = http.StreamedRequest('PUT', uploadUrl)
      ..headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/octet-stream',
      })
      ..contentLength = inputFile.lengthSync();

    // Dosyayı RAM'e almadan parçalar halinde HTTP soketine akıtıyoruz:
    inputFile.openRead().listen(
      uploadRequest.sink.add,
      onDone: uploadRequest.sink.close,
      onError: uploadRequest.sink.addError,
      cancelOnError: true,
    );

    final streamedResponse = await uploadRequest.send();
    final uploadRes = await http.Response.fromStream(streamedResponse);

    if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
      throw Exception('OneDrive yükleme hatası: ${uploadRes.statusCode} - ${uploadRes.body}');
    }

    File? outFile;
    try {
      final convertUrl = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName:/content?format=pdf',
      );

      final pdfRequest = http.Request('GET', convertUrl)
        ..headers.addAll({'Authorization': 'Bearer $accessToken'});

      final pdfStreamedResponse = await pdfRequest.send();

      if (pdfStreamedResponse.statusCode != 200) {
        throw Exception('Microsoft PDF dönüştürme hatası: ${pdfStreamedResponse.statusCode}');
      }

      final workingDir = await TempFileManager.workingDir;
      outFile = File('${workingDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      final sink = outFile.openWrite();
      await pdfStreamedResponse.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      return outFile;
    } catch (e) {
      if (outFile != null && await outFile.exists()) {
        try {
          await outFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      final deleteUrl = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName',
      );
      try {
        await http.delete(
          deleteUrl,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
      } catch (_) {}
    }
  }
}