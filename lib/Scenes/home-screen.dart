import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
import 'pdf_compress_screen.dart';
import 'doc_scanner_screen.dart';
import 'file_share_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _statusMessage;
  final List<File> _resultFiles = [];

  // ================= AKSİYON METOTLARI =================

  Future<void> _handleDirectQrSend() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) return;

    final fileToSend = File(result.files.single.path!);
    const int maxBytes = 50 * 1024 * 1024; // 50 MB

    if (fileToSend.lengthSync() > maxBytes) {
      if (!mounted) return;
      _showFeedbackSnackBar(
        message: 'Seçilen dosya 50 MB sınırını aşıyor!',
        icon: Icons.warning_amber_rounded,
        backgroundColor: Colors.amber.shade900,
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QrShareScreen(file: fileToSend)),
    );
  }

  Future<void> _processCategory({
    required String title,
    required List<String> extensions,
    required String type,
  }) async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result == null || result.files.isEmpty) return;

    if (result.files.length > 10) {
      if (!mounted) return;
      _showFeedbackSnackBar(
        message: 'En fazla 10 dosya seçebilirsiniz! Lütfen tekrar seçin.',
        icon: Icons.info_outline_rounded,
        backgroundColor: Colors.orange.shade800,
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
          _statusMessage = 'İşleniyor (${i + 1}/$total)\n$name';
        });

        if (type == 'office') {
          if (msAuth.isSignedIn) {
            final token = await msAuth.getAccessToken();
            if (token != null) {
              final msService = MicrosoftGraphService(token);
              _resultFiles.insert(0, await msService.convertOfficeToPdf(file));
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
          _resultFiles.insert(0, await driveService.convertOfficeToPdfViaDrive(file));
        } else if (type == 'image') {
          _resultFiles.insert(0, await ImageToPdfConverter.convert(file));
        } else if (type == 'txt') {
          _resultFiles.insert(0, await TxtToPdfConverter.convert(file));
        } else if (type == 'zip') {
          final extracted = await ZipExtractor.extract(file);
          _resultFiles.insertAll(0, extracted);
        }
      }

      _showFeedbackSnackBar(
        message: '$total dosya başarıyla dönüştürüldü.',
        icon: Icons.check_circle_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    } catch (e) {
      _showFeedbackSnackBar(
        message: _hataMesajiniYorumla(e),
        icon: Icons.error_outline_rounded,
        backgroundColor: Colors.red.shade800,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _previewFile(File file) async {
    HapticFeedback.lightImpact();
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      _showFeedbackSnackBar(
        message: 'Dosya açılamadı: ${result.message}',
        icon: Icons.broken_image_rounded,
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _backupSingleFileToDrive(File file) async {
    final googleAuth = context.read<GoogleAuthService>();

    if (!googleAuth.isSignedIn) {
      final success = await googleAuth.signIn();
      if (!success) {
        if (!mounted) return;
        _showFeedbackSnackBar(
          message: 'Yedekleme için Google girişi yapılmadı.',
          icon: Icons.lock_outline_rounded,
          backgroundColor: Colors.amber.shade900,
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _statusMessage = '${file.uri.pathSegments.last}\nDrive\'a aktarılıyor...';
    });

    try {
      final driveService = DriveSyncService(googleAuth);
      await driveService.uploadPdfToDrive(file);

      if (!mounted) return;
      _showFeedbackSnackBar(
        message: '${file.uri.pathSegments.last} Drive\'a yüklendi!',
        icon: Icons.cloud_done_rounded,
        backgroundColor: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar(
        message: 'Yükleme hatası: $e',
        icon: Icons.error_rounded,
        backgroundColor: Colors.red.shade800,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _handlePdfCompression() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) return;
    if (!mounted) return;

    final selectedPdf = File(result.files.single.path!);
    final File? compressed = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => PdfCompressScreen(file: selectedPdf)),
    );

    if (compressed != null && mounted) {
      setState(() => _resultFiles.insert(0, compressed));
      _showFeedbackSnackBar(
        message: 'Sıkıştırılmış PDF hazırlandı!',
        icon: Icons.compress_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    }
  }

  Future<void> _handleDocScanner() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || !mounted) return;

    final imageFiles = pickedFiles.map((x) => File(x.path)).toList();
    final File? outputPdf = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (context) => DocScannerScreen(initialImages: imageFiles)),
    );

    if (outputPdf != null && mounted) {
      setState(() => _resultFiles.insert(0, outputPdf));
      _showFeedbackSnackBar(
        message: 'Taranmış A4 PDF başarıyla oluşturuldu!',
        icon: Icons.document_scanner_rounded,
        backgroundColor: Colors.deepPurple.shade600,
      );
    }
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
      });
      _showFeedbackSnackBar(
        message: '${files.length} dosya ZIP arşivlendi!',
        icon: Icons.archive_rounded,
        backgroundColor: Colors.brown.shade700,
      );
    } catch (e) {
      _showFeedbackSnackBar(
        message: 'ZIP hatası: $e',
        icon: Icons.error_rounded,
        backgroundColor: Colors.red.shade800,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _backupToGoogleDrive() async {
    if (_resultFiles.isEmpty) return;

    final googleAuth = context.read<GoogleAuthService>();

    if (!googleAuth.isSignedIn) {
      final success = await googleAuth.signIn();
      if (!success) {
        if (!mounted) return;
        _showFeedbackSnackBar(
          message: 'Yedekleme için Google girişi onaylanmadı.',
          icon: Icons.lock_outline_rounded,
          backgroundColor: Colors.amber.shade900,
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Google Drive\'a toplu aktarım başlatılıyor...';
    });

    try {
      final driveService = DriveSyncService(googleAuth);
      int count = 0;

      for (final file in _resultFiles) {
        await driveService.uploadPdfToDrive(file);
        count++;
        setState(() {
          _statusMessage = 'Drive\'a yükleniyor ($count/${_resultFiles.length})...';
        });
      }

      if (!mounted) return;
      _showFeedbackSnackBar(
        message: '$count dosya Drive\'a yedeklendi!',
        icon: Icons.cloud_done_rounded,
        backgroundColor: Colors.teal.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar(
        message: 'Yedekleme hatası: $e',
        icon: Icons.error_rounded,
        backgroundColor: Colors.red.shade800,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusMessage = null;
        });
      }
    }
  }

  String _hataMesajiniYorumla(dynamic e) {
    final s = e.toString().toLowerCase();
    if (s.contains('socketexception') || s.contains('network') || s.contains('failed host lookup')) {
      return 'İnternet bağlantınızı kontrol edin.';
    } else if (s.contains('unauthorized') || s.contains('401')) {
      return 'Oturum zaman aşımına uğradı, tekrar giriş yapın.';
    } else if (s.contains('timeout')) {
      return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
    }
    return 'İşlem gerçekleştirilemedi: ${e.toString().replaceAll('Exception:', '').trim()}';
  }

  void _showFeedbackSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ================= UI BUILD METOTLARI =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Akıcı Modern SliverAppBar
              SliverAppBar.large(
                title: const Text(
                  'Dönüştürücü Paneli',
                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                actions: [
                  IconButton.filledTonal(
                    tooltip: 'PC\'ye QR ile Aktar',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _busy ? null : _handleDirectQrSend,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Çıkış Yap',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () async {
                      if (msAuth.isSignedIn) await msAuth.signOut();
                      if (googleAuth.isSignedIn) await googleAuth.signOut();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // 2. Kullanıcı Profil ve Durum Kartı
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildAccountStatusHeader(context, googleAuth, msAuth),
                ),
              ),

              // 3. Bölüm: Popüler ve Hızlı İşlemler (Hızlı Erişim)
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Öne Çıkanlar & Hızlı Erişim',
                  icon: Icons.bolt_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildFeatureCard(
                      title: 'PC\'ye Gönder',
                      subtitle: 'Wi-Fi / QR Drop',
                      icon: Icons.qr_code_2_rounded,
                      accentColor: Colors.teal,
                      onTap: _handleDirectQrSend,
                    ),
                    _buildFeatureCard(
                      title: 'Belge Tara',
                      subtitle: 'Kameradan A4 PDF',
                      icon: Icons.document_scanner_rounded,
                      accentColor: Colors.deepPurple,
                      onTap: _handleDocScanner,
                    ),
                  ]),
                ),
              ),

              // 4. Bölüm: Office Doküman Dönüştürücüler
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'Office Belgeleri to PDF',
                  icon: Icons.cloud_sync_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildCompactActionCard(
                      title: 'Word',
                      extension: '.docx',
                      icon: Icons.description_rounded,
                      color: const Color(0xFF185ABD),
                      onTap: () => _processCategory(
                        title: 'Word',
                        extensions: ['docx', 'doc'],
                        type: 'office',
                      ),
                    ),
                    _buildCompactActionCard(
                      title: 'Excel',
                      extension: '.xlsx',
                      icon: Icons.table_chart_rounded,
                      color: const Color(0xFF107C41),
                      onTap: () => _processCategory(
                        title: 'Excel',
                        extensions: ['xlsx', 'xls'],
                        type: 'office',
                      ),
                    ),
                    _buildCompactActionCard(
                      title: 'PowerPoint',
                      extension: '.pptx',
                      icon: Icons.slideshow_rounded,
                      color: const Color(0xFFC43E1C),
                      onTap: () => _processCategory(
                        title: 'PowerPoint',
                        extensions: ['pptx', 'ppt'],
                        type: 'office',
                      ),
                    ),
                  ]),
                ),
              ),

              // 5. Bölüm: PDF Araç Kutusu ve Arşiv
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  title: 'PDF ve Arşiv Araçları',
                  icon: Icons.build_circle_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildFeatureCard(
                      title: 'Resim to PDF',
                      subtitle: 'JPG / PNG derle',
                      icon: Icons.collections_rounded,
                      accentColor: Colors.purple.shade600,
                      onTap: () async {
                        final File? singlePdf = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const ImageToPdfScreen()),
                        );
                        if (singlePdf != null && mounted) {
                          setState(() => _resultFiles.insert(0, singlePdf));
                          _showFeedbackSnackBar(
                            message: 'Resimler PDF yapıldı!',
                            icon: Icons.check_circle_rounded,
                            backgroundColor: Colors.purple.shade700,
                          );
                        }
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Birleştir',
                      subtitle: 'Dosyaları bağla',
                      icon: Icons.merge_type_rounded,
                      accentColor: Colors.deepOrange.shade600,
                      onTap: () async {
                        final File? merged = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfMergeScreen()),
                        );
                        if (merged != null && mounted) {
                          setState(() => _resultFiles.insert(0, merged));
                        }
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Sayfa Ayıkla',
                      subtitle: 'İstediğin sayfaları böl',
                      icon: Icons.call_split_rounded,
                      accentColor: Colors.indigo.shade600,
                      onTap: () async {
                        final File? extracted = await Navigator.push<File>(
                          context,
                          MaterialPageRoute(builder: (context) => const PdfSplitScreen()),
                        );
                        if (extracted != null && mounted) {
                          setState(() => _resultFiles.insert(0, extracted));
                        }
                      },
                    ),
                    _buildFeatureCard(
                      title: 'PDF Küçült',
                      subtitle: 'Boyut optimizasyonu',
                      icon: Icons.compress_rounded,
                      accentColor: Colors.blueGrey.shade700,
                      onTap: _handlePdfCompression,
                    ),
                    _buildFeatureCard(
                      title: 'ZIP Oluştur',
                      subtitle: 'Dosyaları paketle',
                      icon: Icons.archive_rounded,
                      accentColor: Colors.brown.shade600,
                      onTap: _handleCreateZip,
                    ),
                    _buildFeatureCard(
                      title: 'ZIP Ayıkla',
                      subtitle: 'Arşivden çıkart',
                      icon: Icons.folder_zip_rounded,
                      accentColor: Colors.amber.shade800,
                      onTap: () => _processCategory(
                        title: 'ZIP',
                        extensions: ['zip'],
                        type: 'zip',
                      ),
                    ),
                  ]),
                ),
              ),

              // 6. Çıktı Dosyaları (Listelenen Alan)
              if (_resultFiles.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Hazır Dosyalar (${_resultFiles.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: const Text('Tümünü Yedekle'),
                          onPressed: _busy ? null : _backupToGoogleDrive,
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Tümünü Paylaş',
                          icon: const Icon(Icons.share_rounded, size: 18),
                          onPressed: _busy
                              ? null
                              : () {
                            final paths = _resultFiles.map((f) => XFile(f.path)).toList();
                            Share.shareXFiles(paths);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildResultTile(_resultFiles[index], colorScheme, theme),
                      childCount: _resultFiles.length,
                    ),
                  ),
                ),
              ] else ...[
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ],
          ),

          // 7. İşlem Sırasında Gösterilen Şık Progress Overlay
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 3),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage ?? 'İşlem yürütülüyor...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= YARDIMCI BİLEŞENLER =================

  Widget _buildAccountStatusHeader(
      BuildContext context,
      GoogleAuthService googleAuth,
      MicrosoftAuthService msAuth,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMs = msAuth.isSignedIn;
    final isGoogle = googleAuth.isSignedIn;

    final title = isMs
        ? 'Microsoft Hesabı Bağlı'
        : (isGoogle ? (googleAuth.currentUser?.email ?? 'Google Hesabı Bağlı') : 'Misafir / Çevrimdışı Mod');

    final color = isMs
        ? const Color(0xFF0078D4)
        : (isGoogle ? Colors.green.shade700 : colorScheme.outline);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              isMs
                  ? Icons.window_rounded
                  : (isGoogle ? Icons.account_circle_rounded : Icons.person_outline_rounded),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isMs || isGoogle ? 'Bulut entegrasyonu aktif' : 'Giriş yaparak Drive/MS özelliklerini açın',
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Max 10 Dosya',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : onTap,
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionCard({
    required String title,
    required String extension,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                extension,
                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
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
    final fileSizeKB = (file.existsSync() ? file.lengthSync() / 1024 : 0).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: () => _previewFile(file),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPdf ? Colors.red.withValues(alpha: 0.1) : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
            color: isPdf ? Colors.red.shade700 : colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          '$fileSizeKB KB • Dokun ve Görüntüle',
          style: TextStyle(fontSize: 11, color: colorScheme.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'QR ile PC\'ye Aktar',
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              color: Colors.teal.shade700,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QrShareScreen(file: file)),
                );
              },
            ),
            IconButton(
              tooltip: 'Drive\'a Yükle',
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              color: Colors.blue.shade700,
              onPressed: _busy ? null : () => _backupSingleFileToDrive(file),
            ),
          ],
        ),
      ),
    );
  }
}