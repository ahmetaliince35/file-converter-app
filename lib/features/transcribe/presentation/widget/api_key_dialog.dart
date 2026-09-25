import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/audio_to_text_converter.dart';

void showApiKeyDialog(BuildContext context, {VoidCallback? onSaved}) {
  final controller = TextEditingController();

  AudioToTextConverter.getSavedApiKey().then((val) {
    if (val != null) controller.text = val;
  });

  Future<void> openDeepgramConsole() async {
    final url = Uri.parse('https://console.deepgram.com/');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[URL_LAUNCH_HATA] Link açılamadı: $e');
    }
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.key_rounded, size: 22),
          SizedBox(width: 8),
          Text('Deepgram API Anahtarı', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ücretsiz API anahtarınızı girin:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Deepgram API Anahtarı',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nasıl Alınır? (Ücretsiz ~750 Saat / Kredi Kartı Bilgisi Gerekmez):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildStepRow('1', 'console.deepgram.com adresine ücretsiz kaydolun.'),
            _buildStepRow('2', 'Girişte anket/tanıtım ekranı gelirse "Skip" butonuna basın.'),
            _buildStepRow('3', 'Sol menüden "API Keys" sekmesine tıklayın.'),
            _buildStepRow('4', '"Create a New API Key" butonuna basın.'),
            _buildStepRow('5', 'Advanced sekmesinde Rol seçimini "Admin" yapın. (Kalan saatinizi ve kredinizi canlı görebilmeniz için gereklidir).'),
            _buildStepRow('6', 'Oluşturulan anahtarı kopyalayıp buraya yapıştırın.'),
            const SizedBox(height: 14),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: openDeepgramConsole,
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('Deepgram Console Sayfasını Aç'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () async {
            final key = controller.text.trim();
            if (key.isNotEmpty) {
              await AudioToTextConverter.saveApiKey(key);
              if (ctx.mounted) Navigator.pop(ctx);
              onSaved?.call();
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

Widget _buildStepRow(String number, String text, {bool isHighlight = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlight ? Colors.teal : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.teal.shade800 : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}