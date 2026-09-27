import axios from 'axios';

// Render'da VITE_API_URL tanımlandığında doğrudan Render backend domainine gider.
// Localde çalışırken varsayılan olarak http://localhost:8000 kullanılır.
export const API_BASE_URL = 
  import.meta.env.VITE_API_URL || 
  'https://file-converter-app-9j0k.onrender.com';

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 300000, // Büyük dosyalar için 5 dakika timeout
});

// CamScanner Köşe Tespiti
export const detectCornersApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/camscanner/detect-corners', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// CamScanner Perspektif Düzeltme & Filtreleme
export const camScannerApi = async (file, points, filterMode = 'magic') => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('points', JSON.stringify(points));
  formData.append('filter_mode', filterMode);

  return await api.post('/api/camscanner/process', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    responseType: 'arraybuffer',
  });
};

// OCR Metin Tanıma
export const ocrApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/ocr', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// PDF Sayfa Küçük Resimleri (Thumbnails)
export const getPdfThumbnailsApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return await api.post('/api/pdf/thumbnails', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// PDF Sayfa Ayıklama
export const extractPdfPagesApi = async (file, pagesStr) => {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('pages', pagesStr);

  return await api.post('/api/pdf/extract-pages', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    responseType: 'arraybuffer',
  });
};

// Toplu Dosya Dönüştürme & PDF Birleştirme
export const convertBatchApi = async (files, action) => {
  const formData = new FormData();
  files.forEach((f) => formData.append('files', f));
  formData.append('action', action);

  return await api.post('/api/convert/batch', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    responseType: 'arraybuffer',
  });
};

// Mobil Paylaşım Linki / QR Kodu Oluşturma
export const createShareLinkApi = async (file) => {
  const formData = new FormData();
  formData.append('file', file);

  return await api.post('/api/share/create', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};