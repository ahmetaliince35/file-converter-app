import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_converter/core/errors/error_mapper.dart';

void main() {
  test('ağ hatalarını kısa kullanıcı mesajına çevirir', () {
    expect(
      mapErrorMessage(Exception('SocketException: failed host lookup')),
      'İnternet bağlantınızı kontrol edin.',
    );
  });

  test('401 hatalarını oturum mesajına çevirir', () {
    expect(
      mapErrorMessage(Exception('unauthorized 401')),
      'Oturum zaman aşımına uğradı, tekrar giriş yapın.',
    );
  });
}
