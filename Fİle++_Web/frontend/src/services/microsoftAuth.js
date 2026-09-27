import axios from "axios";

// Azure Portal'dan alacağın Client ID (Örn: 00000000-0000-0000-0000-000000000000)
const CLIENT_ID = "YOUR_AZURE_CLIENT_ID";
const REDIRECT_URI = window.location.origin;
const SCOPES = "Files.ReadWrite User.Read";

export const convertOfficeWithGraph = async (file) => {
  if (CLIENT_ID === "YOUR_AZURE_CLIENT_ID") {
    throw new Error(
      "Lütfen microsoftAuth.js içine geçerli bir Azure Client ID tanımlayın."
    );
  }

  // 1. Basit OAuth 2.0 Popup ile Access Token Alma
  const authUrl = `https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=${CLIENT_ID}&response_type=token&redirect_uri=${encodeURIComponent(
    REDIRECT_URI
  )}&scope=${encodeURIComponent(SCOPES)}`;

  const popup = window.open(authUrl, "ms_login", "width=600,height=700");

  const token = await new Promise((resolve, reject) => {
    const timer = setInterval(() => {
      try {
        if (!popup || popup.closed) {
          clearInterval(timer);
          reject(new Error("Giriş penceresi kapatıldı."));
          return;
        }
        if (popup.location.href.includes(REDIRECT_URI)) {
          const hash = popup.location.hash;
          const params = new URLSearchParams(hash.replace("#", "?"));
          const accessToken = params.get("access_token");
          if (accessToken) {
            clearInterval(timer);
            popup.close();
            resolve(accessToken);
          }
        }
      } catch {
        // Cross-origin yönlendirme esnasında hata vermesini engelle
      }
    }, 500);
  });

  // 2. Dosyayı OneDrive'a Yükle
  const tempName = `temp_${Date.now()}_${file.name}`;
  const uploadUrl = `https://graph.microsoft.com/v1.0/me/drive/root:/FilePlus_Temp/${tempName}:/content`;

  const uploadRes = await axios.put(uploadUrl, file, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": file.type || "application/octet-stream",
    },
  });

  const itemId = uploadRes.data.id;

  // 3. Microsoft Graph üzerinden doğrudan PDF olarak çek
  const convertUrl = `https://graph.microsoft.com/v1.0/me/drive/items/${itemId}/content?format=pdf`;
  const pdfRes = await axios.get(convertUrl, {
    headers: { Authorization: `Bearer ${token}` },
    responseType: "blob",
  });

  // 4. OneDrive'daki geçici dosyayı temizle
  try {
    await axios.delete(`https://graph.microsoft.com/v1.0/me/drive/items/${itemId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
  } catch (err) {
    console.warn("Geçici dosya silinemedi:", err);
  }

  return pdfRes.data;
};