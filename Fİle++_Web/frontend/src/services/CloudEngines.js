import axios from 'axios';

// -------------------------------------------------------------
// 1. MICROSOFT GRAPH ENTEGRASYONU
// -------------------------------------------------------------

// OneDrive / Office Motoru ile PDF'e Çevirme (Geçici İşlem)
export const convertWithMicrosoft = async (file, token) => {
  const tempName = `temp_${Date.now()}_${file.name}`;
  const uploadUrl = `https://graph.microsoft.com/v1.0/me/drive/root:/FilePlus_Temp/${tempName}:/content`;

  const uploadRes = await axios.put(uploadUrl, file, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': file.type || 'application/octet-stream',
    },
  });

  const itemId = uploadRes.data.id;
  const convertUrl = `https://graph.microsoft.com/v1.0/me/drive/items/${itemId}/content?format=pdf`;

  const pdfRes = await axios.get(convertUrl, {
    headers: { Authorization: `Bearer ${token}` },
    responseType: 'blob',
  });

  // Geçici dosyayı sil
  try {
    await axios.delete(`https://graph.microsoft.com/v1.0/me/drive/items/${itemId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
  } catch {}

  return pdfRes.data;
};

// OneDrive'a Kalıcı Dosya Kaydetme / Senkronize Etme
export const saveToOneDrive = async (blob, fileName, token) => {
  const targetUrl = `https://graph.microsoft.com/v1.0/me/drive/root:/FilePlus_Documents/${fileName}:/content`;

  const res = await axios.put(targetUrl, blob, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': blob.type || 'application/octet-stream',
    },
  });

  return res.data;
};

// -------------------------------------------------------------
// 2. GOOGLE DRIVE ENTEGRASYONU
// -------------------------------------------------------------

// Google Docs Motoru ile PDF'e Çevirme (Geçici İşlem)
export const convertWithGoogle = async (file, token) => {
  const metadata = {
    name: file.name,
    mimeType: 'application/vnd.google-apps.document',
  };

  const formData = new FormData();
  formData.append(
    'metadata',
    new Blob([JSON.stringify(metadata)], { type: 'application/json' })
  );
  formData.append('file', file);

  const uploadRes = await axios.post(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    formData,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  const fileId = uploadRes.data.id;

  // PDF olarak dışa aktar (Export)
  const exportUrl = `https://www.googleapis.com/drive/v3/files/${fileId}/export?mimeType=application/pdf`;
  const pdfRes = await axios.get(exportUrl, {
    headers: { Authorization: `Bearer ${token}` },
    responseType: 'blob',
  });

  // Geçici dosyayı sil
  try {
    await axios.delete(`https://www.googleapis.com/drive/v3/files/${fileId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
  } catch {}

  return pdfRes.data;
};

// Google Drive Klasörünü Bul veya Yoksa Aç
const getOrCreateDriveFolder = async (folderName, token) => {
  const q = `name='${folderName}' and mimeType='application/vnd.google-apps.folder' and trashed=false`;
  const searchRes = await axios.get(
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id,name)`,
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );

  if (searchRes.data.files && searchRes.data.files.length > 0) {
    return searchRes.data.files[0].id;
  }

  // Klasör yoksa oluştur
  const createRes = await axios.post(
    'https://www.googleapis.com/drive/v3/files',
    {
      name: folderName,
      mimeType: 'application/vnd.google-apps.folder',
    },
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    }
  );

  return createRes.data.id;
};



export const saveToGoogleDrive = async (blob, fileName, token) => {
  if (!token) throw new Error("Google oturumu bulunamadı.");

  const contentType = blob.type || 'application/octet-stream';

  // 1. Dosya Meta Verisi Oluştur
  const metadata = {
    name: fileName,
    mimeType: contentType,
  };

  // 2. Resumable Upload Başlat
  const initRes = await axios.post(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
    metadata,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': contentType,
        'X-Upload-Content-Length': blob.size.toString(),
      },
    }
  );

  const uploadLocation = initRes.headers.location;

  // 3. Gerçek Binary Dosyayı Yükle
  const uploadRes = await axios.put(uploadLocation, blob, {
    headers: {
      'Content-Type': contentType,
    },
  });

  return uploadRes.data;
};