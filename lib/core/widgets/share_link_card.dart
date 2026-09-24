import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareLinkCard extends StatelessWidget {
  final String webUrl;
  final String pin;

  const ShareLinkCard({
    super.key,
    required this.webUrl,
    required this.pin,
  });

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bağlantı Adresi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      webUrl,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () => _copy(context, webUrl, 'Bağlantı panoya kopyalandı!'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Column(
            children: [
              const Text(
                'GÜVENLİK KODU (PIN)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.indigo),
              ),
              const SizedBox(height: 6),
              Text(
                pin,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Linke giren kullanıcı bu kodu girmelidir.',
                style: TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ],
          ),
        ),
      ],
    );
  }
}