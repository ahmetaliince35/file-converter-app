import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../docs-to-pdf.dart';
import '../image-to-pdf.dart';
import '../pptx-to-pdf.dart';
import '../txt-To-pdf.dart';
import '../xlsx-to-pdf.dart';
import '../zip-extractor.dart';
import '../GoogleAuthService.dart';
import '../drive_Service.dart';
import 'login-screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _statusMessage;
  final List<File> _resultFiles = [];

  Future<void> _pickAndConvert() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['txt', 'jpg', 'jpeg', 'png', 'docx', 'xlsx', 'pptx', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final ext = path.split('.').last.toLowerCase();
    final file = File(path);

    setState(() {
      _busy = true;
      _statusMessage = 'Dönüştürülüyor...';
      _resultFiles.clear();
    });

    try {
      switch (ext) {
        case 'txt':
          _resultFiles.add(await TxtToPdfConverter.convert(file));
          break;
        case 'jpg':
        case 'jpeg':
        case 'png':
          _resultFiles.add(await ImageToPdfConverter.convert(file));
          break;
        case 'docx':
          _resultFiles.add(await DocxToPdfConverter.convert(file));
          break;
        case 'xlsx':
          _resultFiles.add(await XlsxToPdfConverter.convert(file));
          break;
        case 'pptx':
          _resultFiles.add(await PptxToPdfConverter.convert(file));
          break;
        case 'zip':
          _resultFiles.addAll(await ZipExtractor.extract(file));
          break;
        default:
          throw UnsupportedError('Desteklenmeyen dosya türü: .$ext');
      }
      setState(() => _statusMessage = 'Tamamlandı: ${_resultFiles.length} dosya.');
    } catch (e) {
      setState(() => _statusMessage = 'Hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _syncToDrive() async {
    final auth = context.read<GoogleAuthService>();
    if (!auth.isSignedIn) {
      final ok = await auth.signIn();
      if (!ok) return;
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Drive\'a yükleniyor...';
    });

    try {
      final driveService = DriveSyncService(auth);
      for (final file in _resultFiles) {
        await driveService.uploadFile(file, folderName: 'Dosya Converter');
      }
      setState(() => _statusMessage = '${_resultFiles.length} dosya Drive\'a yüklendi.');
    } catch (e) {
      setState(() => _statusMessage = 'Senkron hatası: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dosya Converter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LoginScreen(),
            const Divider(height: 32),
            Text(
              'Desteklenen: txt, jpg/png, docx, xlsx, pptx → PDF  •  zip → ayıklama',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickAndConvert,
              icon: const Icon(Icons.file_open),
              label: const Text('Dosya Seç ve Dönüştür'),
            ),
            const SizedBox(height: 12),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_statusMessage!, textAlign: TextAlign.center),
              ),
            if (_resultFiles.isNotEmpty) ...[
              const Divider(),
              const Text('Sonuç Dosyaları', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._resultFiles.map(
                    (f) => ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(f.uri.pathSegments.last),
                  trailing: IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.shareXFiles([XFile(f.path)]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _syncToDrive,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Drive\'a Senkronize Et'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}