import axios from 'axios';

// Render'da VITE_API_URL tanımlandığında doğrudan backend domainine gider.
// Localde çalışırken varsayılan olarak http://localhost:8000 kullanılır.
export const API_BASE_URL = (
  import.meta.env.VITE_API_URL || 'http://localhost:8000'
).replace(/\/+$/, '');

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000, // Varsayılan 30 saniye
});

// 1. CamScanner Köşe Tespiti (/api/camscanner/detect-corners)
export const detectCornersApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/camscanner/detect-corners', formData);
};

// 2. CamScanner Perspektif Düzeltme & Filtreleme (/api/camscanner)
export const camScannerApi = async (file, points, filterMode = 'magic') => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('points', JSON.stringify(points));
  formData.append('filter_mode', filterMode);

  return await api.post('/api/camscanner', formData, {
    responseType: 'blob',
    timeout: 60000, // Görsel işleme için 60 sn
  });
};

// 3. OCR Metin Tanıma (/api/ocr)
export const ocrApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/ocr', formData, {
    timeout: 120000, // EasyOCR CPU üzerinde vakit alabilir (2 dk)
  });
};

// 4. PDF Sayfa Önizlemeleri (/api/pdf-thumbnails)
export const getPdfThumbnailsApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/pdf-thumbnails', formData);
};

// 5. PDF Sayfa Ayıklama (/api/pdf-extract)
export const extractPdfPagesApi = async (file, pagesStr) => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('pages', pagesStr);

  return await api.post('/api/pdf-extract', formData, {
    responseType: 'blob',
  });
};

// 6. Toplu Dosya Dönüştürme, PDF Birleştirme & ZIP (/api/convert-batch)
export const convertBatchApi = async (files, targetFormat) => {
  const formData = new FormData();
  files.forEach((f) => formData.append('files', f));
  // Backend 'target_format' bekliyor ('action' değil!)
  formData.append('target_format', targetFormat);

  return await api.post('/api/convert-batch', formData, {
    responseType: 'blob',
    timeout: 300000, // Dönüştürme ve birleştirme için 5 dk
  });
};

// 7. Görsellerden PDF Oluşturma (/api/images-to-pdf)
export const imagesToPdfApi = async (files) => {
  const formData = new FormData();
  files.forEach((f) => formData.append('files', f));

  return await api.post('/api/images-to-pdf', formData, {
    responseType: 'blob',
  });
};

// 8. PDF Bilgisi (/api/pdf-info)
export const getPdfInfoApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/pdf-info', formData);
};

// 9. Mobil Paylaşım Linki / QR Kodu Oluşturma (/api/share/create)
export const createShareLinkApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/share/create', formData);
};