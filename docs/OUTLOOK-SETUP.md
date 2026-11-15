# Outlook / Microsoft 365 kurulumu

Sift şifre veya client secret istemez. Microsoft girişi tarayıcıda gerçekleşir; kişisel Outlook.com ve iş/okul Microsoft 365 hesapları desteklenir. Kurumun güvenlik politikaları yönetici onayı gerektirebilir veya cihaz koduyla girişi engelleyebilir.

## Yayıncı için bir kez yapılacak işlem

1. [Microsoft Entra yönetim merkezine](https://entra.microsoft.com/) giriş yap. **Identity → Applications → App registrations → New registration** yolunu aç.
2. Adı **Sift** yap. Hesap türünde **Accounts in any organizational directory and personal Microsoft accounts** seç. Bu seçenek farklı şirketlerin ve kişisel Outlook hesaplarının kendi hesaplarıyla giriş yapmasını sağlar.
3. Kaydı oluştur. **Overview → Application (client) ID** değerini kopyala. Bu herkese açık bir uygulama kimliğidir, şifre değildir.
4. **Authentication → Advanced settings → Allow public client flows → Yes** ayarını etkinleştir. Bu cihaz kodu akışında redirect URI veya client secret gerekmez.
5. **API permissions → Add a permission → Microsoft Graph → Delegated permissions** altında `User.Read`, `Mail.ReadWrite`, `Mail.Send`, `offline_access` izinlerini ekle. **Application permissions** seçme.
6. **Branding & properties** alanına yayıncı iletişimi, gizlilik politikası ve kullanım koşulları bağlantılarını ekle. Geniş dağıtımdan önce yayıncı doğrulamasını ve kuruluşların izin politikalarını değerlendir. Çok kiracılı kayıt, her kuruluşta otomatik onay garantisi değildir.
7. GitHub repository **Settings → Secrets and variables → Actions → Variables** bölümüne `MICROSOFT_CLIENT_ID` adlı **variable** ekle. Değeri 3. adımdaki kimliktir. Sonraki CI paketi bunu Info.plist içine ekler. Kullanıcıların kendi uygulama kaydı açması gerekmez.

Uygulama kaydı veya Entra dizini oluşturma iznin yoksa bu işlem için dizin yöneticisi gerekir. Sift bu kaydı senin adına otomatik oluşturmaz. Hiçbir erişim anahtarını GitHub'a veya sohbete yapıştırma.

## Kullanıcı için

1. Sift → **Hesap ekle** → **Microsoft hesabı bağla**.
2. Dağıtımda yayıncı kimliği yoksa Application (client) ID alanına kendi kaydının kimliğini gir.
3. Uygulamadaki kodu kopyala, açılan Microsoft sayfasına gir ve bağlamak istediğin hesapla izin ver. Microsoft'un gösterdiği uygulama adını ve izinleri kontrol et.
4. İlk eşitlemenin bitmesini bekle. İlk eşitleme geçmiş postalar için çentik bildirimi oluşturmaz. Büyük gelen kutularında bu işlem zaman alabilir.
5. Ayarlar → **Çentik** bölümünden önem eşiğini, görünürlük süresini ve sessiz saatleri seç. **Çentik bildirimini dene** yalnızca örnek veri kullanır.
6. Daha fazla hesap için işlemi tekrarla. Hesap başına erişim anahtarı ve eşitleme durumu ayrıdır.

## İzinler ve sınırlar

- `User.Read`: bağlanan hesabın adını ve e-posta adresini öğrenmek.
- `Mail.ReadWrite`: gelen kutusunu okumak, okundu işaretlemek ve arşivlemek. Sift otomatik posta silmez.
- `Mail.Send`: yalnızca kullanıcının Gönder dediği yanıtları göndermek. 10 saniyelik bekleme sırasında geri alınabilir; Microsoft'a teslim edildikten sonra geri alınamaz.
- `offline_access`: Sift açıkken yeniden giriş istemeden erişimi yenilemek.
- Hesabı kaldırmak yerel veriyi ve Anahtar Zinciri kaydını siler. Microsoft hesabındaki uygulama izinleri sayfasından yetkiyi ayrıca iptal edebilirsin.
- Şimdilik yalnızca gelen kutusu eşitlenir; ekler, HTML, yeni ileti oluşturma, diğer klasörler, Gmail ve IMAP bu sürümde yoktur. Yanıt gönderimi desteklenir.
- Sessize alma ve erteleme sadece Sift'te uygulanır. Arşivleme ve okundu bilgisi Microsoft'a yazılır.
- Eşitleme uygulama açıkken yaklaşık 60 saniyede bir yapılır. Uyku ve ağ hataları gecikmeye neden olabilir.

Kaynaklar: [Microsoft cihaz yetkilendirmesi](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code), [uygulama kaydı](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app), [Graph izinleri](https://learn.microsoft.com/en-us/graph/permissions-reference).
