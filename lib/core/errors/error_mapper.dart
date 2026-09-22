/// Ham istisnaları kullanıcıya gösterilebilir kısa metne çevirir.
String mapErrorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('failed host lookup')) {
    return 'İnternet bağlantınızı kontrol edin.';
  }
  if (text.contains('unauthorized') || text.contains('401')) {
    return 'Oturum zaman aşımına uğradı, tekrar giriş yapın.';
  }
  if (text.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
  }
  return 'İşlem gerçekleştirilemedi: ${error.toString().replaceAll('Exception:', '').trim()}';
}
