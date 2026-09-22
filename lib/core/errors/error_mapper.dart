/// Ham istisnaları kullanıcıya gösterilebilir kısa metne çevirir.
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
  if (text.contains('unauthorized') || text.contains('401')) {
    return 'Oturum zaman aşımına uğradı, lütfen tekrar giriş yapın.';
  }

  // 3. Zaman Aşımı Hataları
  if (text.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
  }

  // 4. Bellek / Depolama Sınırı Hataları
  if (text.contains('outofmemory') || text.contains('out of memory')) {
    return 'Bellek yetersiz. Lütfen daha az veya daha küçük dosyalar seçin.';
  }
  if (text.contains('no space left') || text.contains('os error: 28')) {
    return 'Cihazda yeterli depolama alanı kalmadı.';
  }

  // 5. Desteklenmeyen / Bozuk Dosya Formatları
  if (text.contains('formatexception') || text.contains('invalid archive')) {
    return 'Dosya biçimi bozuk veya desteklenmiyor.';
  }

  // Genel Hata
  final cleanMessage = error.toString().replaceAll('Exception:', '').trim();
  return 'İşlem gerçekleştirilemedi: $cleanMessage';
}