import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/audio_to_text_converter.dart';

void showApiKeyDialog(BuildContext context, {VoidCallback? onSaved}) {
  final controller = TextEditingController();

  AudioToTextConverter.getSavedApiKey().then((val) {
    if (val != null) controller.text = val;
  });

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Groq API Anahtarı'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ses dönüştürme işlemleri Whisper Large-v3 ile saniyeler içinde ücretsiz yapılır. Kendi ücretsiz anahtarınızı girin:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'gsk_...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nasıl Alınır? (1 Dakika, Ücretsiz):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '1. console.groq.com adresine ücretsiz kaydolun.\n'
                  '2. Sol menüden "API Keys" sekmesine girin.\n'
                  '3. "Create API Key" butonuna basıp kodu kopyalayın ve buraya yapıştırın.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://console.groq.com/keys');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Groq Console Sayfasını Aç'),
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