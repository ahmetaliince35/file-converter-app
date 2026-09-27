import 'dart:math';

class ShareAuthHelper {
  static String generatePin() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  static String generateDirectToken() {
    return Random().nextInt(99999999).toString();
  }

  static String buildPinHtml({required String fileName}) {
    return '''
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dosya İndir - Doğrulama</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f1f5f9; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 16px; box-sizing: border-box; }
    .card { background: #ffffff; padding: 32px 24px; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.06); width: 100%; max-width: 360px; text-align: center; }
    .icon { font-size: 40px; margin-bottom: 8px; }
    h2 { margin: 8px 0; font-size: 18px; color: #0f172a; }
    p { font-size: 13px; color: #64748b; margin-bottom: 20px; word-break: break-all; }
    input { width: 100%; padding: 14px; border: 2px solid #cbd5e1; border-radius: 12px; font-size: 24px; text-align: center; letter-spacing: 8px; box-sizing: border-box; outline: none; }
    input:focus { border-color: #4f46e5; }
    button { width: 100%; margin-top: 14px; padding: 14px; background: #4f46e5; color: #fff; border: none; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer; }
    button:active { background: #4338ca; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">📁</div>
    <h2>Doğrulama Kodu Gerekli</h2>
    <p><strong>$fileName</strong> dosyasını indirmek için paylaşılan 4 haneli PIN kodunu girin.</p>
    <form action="/download" method="GET">
      <input type="tel" name="pin" maxlength="4" placeholder="••••" required autofocus pattern="[0-9]{4}">
      <button type="submit">Doğrula ve İndir</button>
    </form>
  </div>
</body>
</html>
''';
  }
}