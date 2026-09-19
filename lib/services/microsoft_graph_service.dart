import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MicrosoftGraphService {
  final String accessToken;

  MicrosoftGraphService(this.accessToken);

  /// Word, Excel veya PPTX dosyasını Microsoft'un resmi motoruyla PDF'e dönüştürür
  Future<File> convertOfficeToPdf(File inputFile) async {
    final fileName = inputFile.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final tempUploadName = 'temp_${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final headers = {
      'Authorization': 'Bearer $accessToken',
    };

    // 1. Dosyayı geçici olarak OneDrive kök dizinine yükle
    final uploadUrl = Uri.parse(
      'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName:/content',
    );
    final fileBytes = await inputFile.readAsBytes();
    final uploadRes = await http.put(uploadUrl, headers: headers, body: fileBytes);

    if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
      throw Exception('OneDrive yükleme hatası: ${uploadRes.statusCode} - ${uploadRes.body}');
    }

    try {
      // 2. Microsoft Word/Office render motorundan orijinal kalitede PDF al
      final convertUrl = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName:/content?format=pdf',
      );
      final pdfRes = await http.get(convertUrl, headers: headers);

      if (pdfRes.statusCode != 200) {
        throw Exception('Microsoft PDF dönüştürme hatası: ${pdfRes.statusCode}');
      }

      // 3. Cihaza yerel dosya olarak kaydet
      final dir = await getApplicationDocumentsDirectory();
      final outFile = File('${dir.path}/$baseName.pdf');
      await outFile.writeAsBytes(pdfRes.bodyBytes);

      return outFile;
    } finally {
      // 4. Geçici yüklenen dosyayı OneDrive'dan temizle
      final deleteUrl = Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/root:/$tempUploadName',
      );
      try {
        await http.delete(deleteUrl, headers: headers);
      } catch (_) {}
    }
  }
}