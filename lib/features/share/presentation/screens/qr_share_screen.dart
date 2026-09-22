import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/file_share_service.dart';

class QrShareScreen extends StatefulWidget {
  final File file;

  const QrShareScreen({super.key, required this.file});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  final QrShareServer _server = QrShareServer();
  String? _downloadUrl;
  bool _isLoading = true;
  String? _error;
  late final String _fileName;
  late final String _fileSizeMb;

  @override
  void initState() {
    super.initState();
    _fileName = p.basename(widget.file.path);
    final bytes = widget.file.existsSync() ? widget.file.lengthSync() : 0;
    _fileSizeMb = (bytes / (1024 * 1024)).toStringAsFixed(2);
    _baslat();
  }

  Future<void> _checkFirstTimeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seenGuide = prefs.getBool('seen_qr_guide') ?? false;

    if (!seenGuide && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _showHelpModal(isFirstTime: true);
        await prefs.setBool('seen_qr_guide', true);
      }
    }
  }

  Future<void> _baslat() async {
    try {
      // HomeScreen ile uyumlu 1 GB sınırı (HTTP streaming bellek tüketmez)
      const int maxLimitBytes = 1024 * 1024 * 1024;
      final fileLength = await widget.file.length();
      if (fileLength > maxLimitBytes) {
        throw Exception('Dosya 1 GB sınırını aşıyor.');
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final url = await _server.start(widget.file);

      if (mounted) {
        setState(() {
          _downloadUrl = url;
          _isLoading = false;
        });
        _checkFirstTimeGuide();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  void _showHelpModal({bool isFirstTime = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Colors.indigo, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Nasıl Kullanılır?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildStepRow(
                number: '1',
                title: 'Aynı Wi-Fi Ağına Bağlanın',
                desc: 'Dosyayı alacak cihaz ile bu telefon aynı Wi-Fi modemine bağlı olmalıdır.',
                icon: Icons.wifi_rounded,
              ),
              const SizedBox(height: 14),
              _buildStepRow(
                number: '2',
                title: 'Kamerayla QR Kodu Okutun',
                desc: 'Karşı cihazın kamerasını açıp ekrandaki QR kodu taratın.',
                icon: Icons.qr_code_scanner_rounded,
              ),
              const SizedBox(height: 14),
              _buildStepRow(
                number: '3',
                title: 'Doğrudan İnsin',
                desc: 'Dosya orijinal formatında yerel ağdan tam hızla iner.',
                icon: Icons.download_rounded,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'İpucu: Sorun yaşarsanız telefonunuzun mobil verisini kapatıp sadece Wi-Fi ile deneyin.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isFirstTime ? 'Anladım, Başla!' : 'Kapat',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR ile Hızlı İndir'),
        actions: [
          TextButton.icon(
            onPressed: () => _showHelpModal(isFirstTime: false),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Nasıl Çalışır?'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _baslat,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      )
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _downloadUrl ?? '',
                  version: QrVersions.auto,
                  size: 220.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _fileName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '$_fileSizeMb MB',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => _showHelpModal(isFirstTime: false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.indigo, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Aynı Wi-Fi ağından kamerayla okutun',
                        style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: Colors.indigo, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}