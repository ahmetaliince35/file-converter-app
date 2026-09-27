/// Ham istisnaları kullanıcıya gösterilebilir kısa ve açıklayıcı metne çevirir.
String mapErrorMessage(Object error) {
  final text = error.toString().toLowerCase();

  // 1. Ağ ve Bağlantı Hataları
  if (text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused')) {
    return 'İnternet bağlantınızı kontrol edin.';
  }

  // 2. Yetkilendirme / Token Hataları
  if (text.contains('unauthorized') ||
      text.contains('401') ||
      text.contains('invalid api key')) {
    return 'Groq API anahtarı geçersiz veya süresi dolmuş. Lütfen anahtarınızı kontrol edin.';
  }

  // 3. Zaman Aşımı Hataları
  if (text.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
  }

  // 4. Bellek / Depolama Sınırı Hataları
  if (text.contains('outofmemory') || text.contains('out of memory')) {
    return 'Bellek yetersiz. Lütfen daha küçük bir dosya seçin.';
  }
  if (text.contains('no space left') || text.contains('os error: 28')) {
    return 'Cihazda yeterli depolama alanı kalmadı.';
  }

  // 5. Groq / Ses Formatı ve Xiaomi Uyumsuzluğu
  if (text.contains('unsupported_audio_format') ||
      text.contains('could not be decoded') ||
      text.contains('corrupt') ||
      text.contains('formatexception')) {
    return 'Seçilen ses formatı çözülemedi. Lütfen standart bir MP3, WAV veya WhatsApp ses kaydı seçin. (Xiaomi cihazlarda Ses Kaydedici ayarlarından formatı MP3 yapabilirsiniz).';
  }

  // 6. Groq Kota / Hız Limiti (Rate Limit)
  if (text.contains('429') || text.contains('rate limit')) {
    return 'Groq API istek limiti aşıldı. Lütfen bir dakika bekleyip tekrar deneyin.';
  }

  // Genel Hata
  final cleanMessage = error.toString().replaceAll('Exception:', '').trim();
  return 'İşlem gerçekleştirilemedi: $cleanMessage';
}