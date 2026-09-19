# Dosya Dönüştürücü Mimari Rehberi

Uygulama kademeli olarak **MVVM** yapısına taşınmıştır. UI yalnızca kullanıcı
etkileşimini ve görünümü yönetir; oturum ve tema gibi ekran durumları
ViewModel'lerde tutulur. Ağ, dosya sistemi ve üçüncü taraf SDK çağrıları servis
katmanında kalır.

```
lib/
  app/                         Uygulama kabuğu ve başlangıç yönlendirmesi
  core/
    theme/                     Uygulama geneli tema ve kalıcı tercih durumu
  features/
    auth/
      presentation/
        view_models/           AuthViewModel
  services/                    Google, Microsoft, PDF ve cihaz entegrasyonları
  converter_engine/            Saf dönüşüm motorları
  Scenes/                      Kademeli taşınacak mevcut ekranlar
```

## Akış

`View -> ViewModel -> Service/Converter -> ViewModel -> View`

- `FileConverterApp`, bağımlılıkları Provider ile oluşturur.
- `AuthViewModel`, Google ve Microsoft servislerini tek bir oturum durumu
  altında toplar; `AuthGate` yalnızca bu durumu izler.
- `ThemeViewModel`, tema modunu `SharedPreferences` ile saklar. Sistem ayarı
  ilk varsayılandır; ana ekrandaki ay düğmesi açık/koyu modu seçer.
- `AppTheme`, light/dark renk, kart, uygulama çubuğu ve snackbar görünümünün
  tek kaynağıdır.

## Sonraki ekran taşımaları

`Scenes/` dizinindeki işlevsel ekranlar mevcut davranışı korumak için henüz
yerinde bırakılmıştır. Her biri taşınırken şu şablon kullanılmalıdır:

```
features/<özellik>/
  data/                        SDK ve dosya erişimi uyarlayıcıları
  domain/                      modeller ve servis sözleşmeleri
  presentation/pages/          Widget ekranları
  presentation/view_models/    ChangeNotifier tabanlı ekran durumu
```

Özellikle `HomeScreen` içindeki dosya seçme, dönüştürme, Drive'a yükleme ve
sonuç listesi durumları `HomeViewModel`'e; PDF birleştirme/sıkıştırma/bölme ve
tarama ekranlarındaki işlem durumları ise kendi özellik ViewModel'lerine
taşınmalıdır. Bu, bu işlemlerin widget testi yerine birim testiyle denenmesini
sağlar.

## Uygulama önerileri

1. Servislerdeki statik çağrıları arayüz üzerinden enjekte edin.
2. Geçici dosyalar için işlem sonunda veya uygulama açılışında kontrollü temizlik
   politikası oluşturun; kullanıcı tarafından seçilen dosyaları silmeyin.
3. Office dönüşümü için bulut sağlayıcı hatalarını `Failure` modellerine çevirin
   ve kullanıcı metinlerini UI katmanında gösterin.
4. Büyük PDF ve görsel işlerini iptal edilebilir arka plan görevlerine ayırın.
