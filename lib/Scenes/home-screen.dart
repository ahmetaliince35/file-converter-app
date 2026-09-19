import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/zip_creator_service.dart';
import '../Scenes/pdf_page-splitter_screen.dart';
import '../../converter_engine/image-to-pdf.dart';
import '../../converter_engine/txt-To-pdf.dart';
import '../../converter_engine/zip-extractor.dart';
import '../services/drive_Service.dart';
import '../services/GoogleAuthService.dart';
import '../services/microsoft_auth_service.dart';
import '../services/microsoft_graph_service.dart';
import 'pdf_merge_screen.dart';
import 'file_share_screen.dart'; // <-- QR Paylaşım ekranı import edildi

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _statusMessage;
  final List<File> _resultFiles = [];

  // Cihazdan herhangi bir dosyayı seçip doğrudan QR ile bilgisayara aktarma metodu
  Future<void> _handleDirectQrSend() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false, // Tek dosya seçimi
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) return;

    final fileToSend = File(result.files.single.path!);

    // 50 MB sınır kontrolü
    const int maxBytes = 50 * 1024 * 1024;
    if (fileToSend.lengthSync() > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Seçilen dosya 50 MB sınırını aşıyor!'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QrShareScreen(file: fileToSend),
      ),
    );
  }

  Future<void> _processCategory({
    required String title,
    required List<String> extensions,
    required String type,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result == null || result.files.isEmpty) return;

    if (result.files.length > 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En fazla 10 dosya seçebilirsiniz! Lütfen tekrar seçin.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final validFiles = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (validFiles.isEmpty) return;

    setState(() {
      _busy = true;
      _resultFiles.clear();
      _statusMessage = '${validFiles.length} dosya hazırlanıyor...';
    });

    try {
      final googleAuth = context.read<GoogleAuthService>();
      final msAuth = context.read<MicrosoftAuthService>();
      final total = validFiles.length;

      for (int i = 0; i < validFiles.length; i++) {
        final file = validFiles[i];
        final name = file.uri.pathSegments.last;

        setState(() {
          _statusMessage = 'Dönüştürülüyor (${i + 1}/$total): $name';
        });

        if (type == 'office') {
          if (msAuth.isSignedIn) {
            final token = await msAuth.getAccessToken();
            if (token != null) {
              final msService = MicrosoftGraphService(token);
              _resultFiles.add(await msService.convertOfficeToPdf(file));
              continue;
            }
          }

          if (!googleAuth.isSignedIn) {
            final ok = await googleAuth.signIn();
            if (!ok) {
              throw Exception('Office dönüşümü için bir Google veya Microsoft oturumu gereklidir.');
            }
          }
          final driveService = DriveSyncService(googleAuth);
          _resultFiles.add(await driveService.convertOfficeToPdfViaDrive(file));
        } else if (type == 'image') {
          _resultFiles.add(await ImageToPdfConverter.convert(file));
        } else if (type == 'txt') {
          _resultFiles.add(await TxtToPdfConverter.convert(file));
        } else if (type == 'zip') {
          _resultFiles.addAll(await ZipExtractor.extract(file));
        }
      }

      setState(() {
        _statusMessage = '$total dosya başarıyla dönüştürüldü.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = null;
      });
      final mesaj = _hataMesajiniYorumla(e);
      _showErrorToast(mesaj);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _previewFile(File file) async {
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya açılamadı: ${result.message}')),
      );
    }
  }

  Future<void> _backupSingleFileToDrive(File file) async {
    final googleAuth = context.read<GoogleAuthService>();

    if (!googleAuth.isSignedIn) {
      final success = await googleAuth.signIn();
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yedekleme için Google girişi yapılmadı.')),
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _statusMessage = '${file.uri.pathSegments.last} Drive\'a aktarılıyor...';
    });

    try {
      final driveService = DriveSyncService(googleAuth);
      await driveService.uploadPdfToDrive(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${file.uri.pathSegments.last} Drive\'a yüklendi!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme hatası: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  String _hataMesajiniYorumla(dynamic e) {
    final hataStr = e.toString().toLowerCase();

    if (hataStr.contains('socketexception') ||
        hataStr.contains('failed host lookup') ||
        hataStr.contains('network') ||
        hataStr.contains('connection')) {
      return 'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edin.';
    } else if (hataStr.contains('unauthorized') || hataStr.contains('401')) {
      return 'Oturum süresi doldu. Lütfen yeniden giriş yapın.';
    } else if (hataStr.contains('timeout')) {
      return 'Sunucu yanıt vermedi, işlem zaman aşımına uğradı.';
    } else {
      return 'Dönüştürme sırasında bir sorun oluştu. Lütfen tekrar deneyin.';
    }
  }

  void _showErrorToast(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mesaj,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleCreateZip() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;

    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (files.isEmpty) return;

    setState(() {
      _busy = true;
      _statusMessage = 'Dosyalar ZIP arşivine ekleniyor...';
    });

    try {
      final zipFile = await ZipCreatorService.createZipFromFiles(files);
      setState(() {
        _resultFiles.insert(0, zipFile);
        _statusMessage = '${files.length} dosya ZIP yapıldı!';
      });
    } catch (e) {
      _showErrorToast('ZIP oluşturulurken hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _backupToGoogleDrive() async {
    if (_resultFiles.isEmpty) return;

    final googleAuth = context.read<GoogleAuthService>();

    if (!googleAuth.isSignedIn) {
      setState(() => _statusMessage = 'Google Drive bağlantısı kuruluyor...');
      final success = await googleAuth.signIn();
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yedekleme için Google girişi onaylanmadı.')),
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Google Drive\'a yedekleniyor...';
    });

    try {
      final driveService = DriveSyncService(googleAuth);
      int uploadedCount = 0;

      for (final file in _resultFiles) {
        await driveService.uploadPdfToDrive(file);
        uploadedCount++;
        setState(() {
          _statusMessage = 'Drive\'a aktarılıyor ($uploadedCount/${_resultFiles.length})...';
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$uploadedCount dosya Google Drive\'a başarıyla yedeklendi!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yedekleme hatası: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();

    final userTitle = msAuth.isSignedIn
        ? 'Microsoft Hesabı'
        : (googleAuth.currentUser?.email ?? 'Oturum Açıldı');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dönüştürücü Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'PC\'ye Dosya Gönder (QR Drop)',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _busy ? null : _handleDirectQrSend,
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              if (msAuth.isSignedIn) await msAuth.signOut();
              if (googleAuth.isSignedIn) await googleAuth.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: msAuth.isSignedIn ? const Color(0xFF0078D4) : colorScheme.primary,
                    child: Icon(
                      msAuth.isSignedIn ? Icons.window_rounded : Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      userTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Maks: 10 dosya',
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildActionCard(
                  title: 'PowerPoint to PDF',
                  subtitle: '.pptx sunumları',
                  icon: Icons.slideshow_rounded,
                  color: Colors.orange.shade700,
                  onTap: () => _processCategory(
                    title: 'PowerPoint',
                    extensions: ['pptx'],
                    type: 'office',
                  ),
                ),
                _buildActionCard(
                  title: 'Word to PDF',
                  subtitle: '.docx belgeleri',
                  icon: Icons.description_rounded,
                  color: Colors.blue.shade700,
                  onTap: () => _processCategory(
                    title: 'Word',
                    extensions: ['docx'],
                    type: 'office',
                  ),
                ),
                _buildActionCard(
                  title: 'Excel to PDF',
                  subtitle: '.xlsx tabloları',
                  icon: Icons.table_chart_rounded,
                  color: Colors.green.shade700,
                  onTap: () => _processCategory(
                    title: 'Excel',
                    extensions: ['xlsx'],
                    type: 'office',
                  ),
                ),
                _buildActionCard(
                  title: 'Resim to PDF',
                  subtitle: 'JPG, PNG resimleri',
                  icon: Icons.image_rounded,
                  color: Colors.purple.shade600,
                  onTap: () async {
                    final File? tekPdf = await Navigator.push<File>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImageToPdfScreen(),
                      ),
                    );

                    if (tekPdf != null && mounted) {
                      setState(() {
                        _resultFiles.insert(0, tekPdf);
                        _statusMessage = 'Görseller tek bir PDF olarak kaydedildi!';
                      });
                    }
                  },
                ),
                _buildActionCard(
                  title: 'Metin to PDF',
                  subtitle: '.txt notları',
                  icon: Icons.text_snippet_rounded,
                  color: Colors.teal.shade700,
                  onTap: () => _processCategory(
                    title: 'Metin',
                    extensions: ['txt'],
                    type: 'txt',
                  ),
                ),
                _buildActionCard(
                  title: 'ZIP Ayıkla',
                  subtitle: 'Arşiv açıcı',
                  icon: Icons.folder_zip_rounded,
                  color: Colors.amber.shade800,
                  onTap: () => _processCategory(
                    title: 'ZIP',
                    extensions: ['zip'],
                    type: 'zip',
                  ),
                ),
                _buildActionCard(
                  title: 'ZIP Oluştur',
                  subtitle: 'Dosyaları arşivle',
                  icon: Icons.archive_rounded,
                  color: Colors.brown.shade600,
                  onTap: _handleCreateZip,
                ),
                _buildActionCard(
                  title: 'PDF Sayfa Ayıkla',
                  subtitle: 'İstediğin sayfaları al',
                  icon: Icons.call_split_rounded,
                  color: Colors.indigo.shade600,
                  onTap: () async {
                    final File? extractedPdf = await Navigator.push<File>(
                      context,
                      MaterialPageRoute(builder: (context) => const PdfSplitScreen()),
                    );
                    if (extractedPdf != null && mounted) {
                      setState(() {
                        _resultFiles.insert(0, extractedPdf);
                        _statusMessage = 'Seçilen sayfalar yeni PDF yapıldı!';
                      });
                    }
                  },
                ),
                _buildActionCard(
                  title: 'PDF Birleştir & Ekle',
                  subtitle: 'PDF\'leri ardışık bağla',
                  icon: Icons.merge_type_rounded,
                  color: Colors.deepOrange.shade700,
                  onTap: () async {
                    final File? mergedFile = await Navigator.push<File>(
                      context,
                      MaterialPageRoute(builder: (context) => const PdfMergeScreen()),
                    );
                    if (mergedFile != null && mounted) {
                      setState(() {
                        _resultFiles.insert(0, mergedFile);
                        _statusMessage = 'PDF\'ler başarıyla birleştirildi!';
                      });
                    }
                  },
                ),
                // <-- EKLENEN KART: PC'YE DOSYA GÖNDER (QR DROP)
                _buildActionCard(
                  title: 'PC\'ye Gönder (QR)',
                  subtitle: 'Ağdan bilgisayara at',
                  icon: Icons.qr_code_2_rounded,
                  color: Colors.cyan.shade800,
                  onTap: _handleDirectQrSend,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
            ],
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),

            if (_resultFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hazır Dosyalar (${_resultFiles.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: "Google Drive'a Yedekle",
                        icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
                        onPressed: _busy ? null : _backupToGoogleDrive,
                      ),
                      IconButton(
                        tooltip: 'Tümünü Paylaş',
                        icon: const Icon(Icons.share_outlined),
                        onPressed: _busy
                            ? null
                            : () {
                          final paths = _resultFiles.map((f) => XFile(f.path)).toList();
                          Share.shareXFiles(paths);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._resultFiles.map((file) => _buildResultTile(file, colorScheme, theme)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(File file, ColorScheme colorScheme, ThemeData theme) {
    final fileName = file.uri.pathSegments.last;
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        onTap: () => _previewFile(file),
        leading: CircleAvatar(
          backgroundColor: isPdf ? Colors.red.withValues(alpha: 0.12) : colorScheme.primaryContainer,
          child: Icon(
            isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
            color: isPdf ? Colors.red : colorScheme.primary,
          ),
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text('Görüntülemek için dokunun', style: TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hazır dönüştürülmüş dosyayı tek tıkla QR ile bilgisayara atma butonu
            IconButton(
              tooltip: 'QR ile Bilgisayara İndir',
              icon: const Icon(Icons.qr_code_2_rounded, color: Colors.indigo),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QrShareScreen(file: file),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: "Bu dosyayı Drive'a yükle",
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
              onPressed: _busy ? null : () => _backupSingleFileToDrive(file),
            ),
            IconButton(
              tooltip: 'Önizle',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => _previewFile(file),
            ),
          ],
        ),
      ),
    );
  }
}