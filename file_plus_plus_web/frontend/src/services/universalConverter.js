import { jsPDF } from 'jspdf';
import JSZip from 'jszip';

// 150+ Desteklenen Kaynak Kod ve Metin Uzantıları
export const CODE_EXTENSIONS = new Set([
  // Dart & Flutter
  'dart',
  // Web & Fullstack
  'js', 'mjs', 'cjs', 'jsx', 'ts', 'mts', 'cts', 'tsx', 'vue', 'svelte', 'astro',
  'html', 'htm', 'xhtml', 'css', 'scss', 'sass', 'less',
  // Python & Veri Bilimi
  'py', 'pyw', 'pyi', 'pyx', 'r', 'rmd', 'jl', 'ipynb',
  // Sistem & Düşük Seviye Diller
  'c', 'h', 'cpp', 'hpp', 'cc', 'hh', 'cxx', 'hxx', 'ino',
  'cs', 'csx', 'rs', 'go', 'zig', 'nim', 'd', 'v', 'odin', 'pas', 'pp', 'asm', 's',
  'swift', 'm', 'mm',
  // JVM Dilleri
  'java', 'kt', 'kts', 'scala', 'sc', 'groovy', 'gvy', 'gradle', 'clj', 'cljs',
  // Kabuk & Betik Dilleri
  'sh', 'bash', 'zsh', 'fish', 'ksh', 'ps1', 'psm1', 'bat', 'cmd',
  'lua', 'rb', 'rbw', 'rake', 'php', 'phtml', 'pl', 'pm', 'tcl', 'awk', 'sed',
  // Yapılandırılmış Veri & Konfigürasyon
  'json', 'jsonc', 'json5', 'yaml', 'yml', 'toml', 'xml', 'svg', 'csv', 'tsv',
  'ini', 'conf', 'config', 'cfg', 'properties', 'env', 'dotenv', 'lock',
  'mod', 'sum',
  // Veritabanı & Sorgu Dilleri
  'sql', 'mysql', 'pgsql', 'sqlite', 'prisma', 'graphql', 'gql',
  // DevOps & Altyapı
  'dockerfile', 'containerfile', 'makefile', 'cmake', 'vagrantfile', 'jenkinsfile',
  // Dokümantasyon & Notlar
  'md', 'markdown', 'mdx', 'rst', 'tex', 'latex', 'log', 'txt', 'rtf',
  // Shaders & Grafikler
  'glsl', 'hlsl', 'frag', 'vert', 'shader',
  // Fonksiyonel & Diğerleri
  'hs', 'lhs', 'elm', 'erl', 'hrl', 'ex', 'exs', 'fs', 'fsi', 'fsx', 'ml', 'mli',
]);

// Evrensel dönüştürücüde doğrudan çevrilmeyen medya dosyaları
export const BLOCKED_MEDIA_EXTENSIONS = new Set([
  'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg', 'wma', 'opus', 'aiff', 'alac',
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v', 'mpeg', 'mpg',
  'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'heic', 'heif', 'ico', 'raw'
]);

// Yürütülebilir veya doğrudan metin içermeyen ikili sistem dosyaları
export const BLOCKED_BINARY_EXTENSIONS = new Set([
  'exe', 'dll', 'so', 'dylib', 'bin', 'apk', 'aab', 'ipa', 'iso', 'img', 'dmg', 'sys'
]);

export function getFileExtension(filenameOrExt) {
  if (!filenameOrExt) return '';
  const clean = filenameOrExt.startsWith('.') ? filenameOrExt.slice(1) : filenameOrExt;
  const lastDot = clean.lastIndexOf('.');
  if (lastDot === -1) return clean.toLowerCase();
  return clean.substring(lastDot + 1).toLowerCase();
}

export function isCodeFile(filename) {
  const ext = getFileExtension(filename);
  return CODE_EXTENSIONS.has(ext);
}

export function isSupportedCodeExtension(ext) {
  const clean = getFileExtension(ext);
  return CODE_EXTENSIONS.has(clean) || ['txt', 'log', 'md', 'csv', 'json'].includes(clean);
}

export function isArchiveExtension(ext) {
  const clean = getFileExtension(ext);
  return ['zip', 'rar', '7z', 'tar', 'gz', 'bz2'].includes(clean);
}

export function isBlockedMedia(filename) {
  const ext = getFileExtension(filename);
  return BLOCKED_MEDIA_EXTENSIONS.has(ext);
}

export function isBlockedMediaExtension(ext) {
  const clean = getFileExtension(ext);
  return BLOCKED_MEDIA_EXTENSIONS.has(clean);
}

export function isBlockedBinary(filename) {
  const ext = getFileExtension(filename);
  return BLOCKED_BINARY_EXTENSIONS.has(ext);
}

export function isBlockedBinaryExtension(ext) {
  const clean = getFileExtension(ext);
  return BLOCKED_BINARY_EXTENSIONS.has(clean);
}

export function isZipFile(filename) {
  return getFileExtension(filename) === 'zip';
}

/**
 * Çok aşamalı kayıpsız metin çözümleyici (BOM ve karakter kümesi korumalı).
 */
export async function decodeFileToText(fileOrBlob) {
  const buffer = await fileOrBlob.arrayBuffer();
  const bytes = new Uint8Array(buffer);

  // 1. UTF-8 BOM kontrolü (0xEF, 0xBB, 0xBF)
  if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
    const decoder = new TextDecoder('utf-8');
    return decoder.decode(bytes.subarray(3));
  }

  // 2. UTF-16 LE BOM kontrolü (0xFF, 0xFE)
  if (bytes.length >= 2 && bytes[0] === 0xFF && bytes[1] === 0xFE) {
    try {
      const decoder = new TextDecoder('utf-16le');
      return decoder.decode(bytes.subarray(2));
    } catch {}
  }

  // 3. UTF-16 BE BOM kontrolü (0xFE, 0xFF)
  if (bytes.length >= 2 && bytes[0] === 0xFE && bytes[1] === 0xFF) {
    try {
      const decoder = new TextDecoder('utf-16be');
      return decoder.decode(bytes.subarray(2));
    } catch {}
  }

  // 4. Standart UTF-8 çözümleme
  try {
    const decoder = new TextDecoder('utf-8', { fatal: false });
    return decoder.decode(bytes);
  } catch {
    // 5. Latin1 (ISO-8859-1 / Windows-1254) fallback
    const decoder = new TextDecoder('iso-8859-1');
    return decoder.decode(bytes);
  }
}

/**
 * Belleği ve tarayıcı thread'ini şişirmeden monospaced satır numaralı A4 PDF üretir.
 */
export async function convertTextOrCodeToPdf(file, progressCallbackOrOptions = null) {
  const onProgress = typeof progressCallbackOrOptions === 'function' 
    ? progressCallbackOrOptions 
    : progressCallbackOrOptions?.onProgress;

  const isCode = isCodeFile(file.name);
  const textContent = await decodeFileToText(file);
  const lines = textContent.split('\n');

  const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4', compress: true });
  const margin = 14;
  const pageWidth = 210 - margin * 2;
  const pageHeight = 297 - margin * 2;
  const fontSize = isCode ? 7.5 : 8.5;
  const lineHeight = isCode ? 3.4 : 4.0;

  // Başlık Sayfası / Üstbilgi
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.setTextColor(30, 41, 59);
  doc.text(file.name, margin, margin);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(100, 116, 139);
  doc.text(isCode ? 'File++ Kaynak Kodu Belgesi' : 'File++ Belge Stüdyosu', 210 - margin, margin, { align: 'right' });

  // Çizgi
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.line(margin, margin + 2.5, 210 - margin, margin + 2.5);

  let cursorY = margin + 8;
  doc.setFont(isCode ? 'courier' : 'helvetica', 'normal');
  doc.setFontSize(fontSize);
  doc.setTextColor(15, 23, 42);

  const totalLines = lines.length;

  for (let i = 0; i < totalLines; i++) {
    const rawLine = lines[i].replace(/\r/g, '');
    const lineNumberStr = isCode ? `${String(i + 1).padStart(4, ' ')} | ` : '';
    const fullLine = lineNumberStr + rawLine;

    // Satırı sayfa genişliğine göre böl
    const sublines = doc.splitTextToSize(fullLine, pageWidth);

    for (let j = 0; j < sublines.length; j++) {
      if (cursorY > pageHeight) {
        doc.addPage();
        cursorY = margin + 4;
      }
      doc.text(sublines[j], margin, cursorY);
      cursorY += lineHeight;
    }

    if (i % 300 === 0 && onProgress) {
      onProgress({
        percent: Math.round((i / totalLines) * 100),
        lines: i,
        total: totalLines,
        message: `${i} / ${totalLines} satır işlendi...`
      });
      await new Promise((r) => setTimeout(r, 0));
    }
  }

  onProgress?.({ percent: 100, lines: totalLines, total: totalLines, message: 'Tamamlandı' });
  return doc.output('blob');
}

/**
 * ZIP dosyasını açıp içindeki dosyaları listeler (Tarayıcı çökmesini engeller).
 */
export async function inspectZipArchive(zipFile) {
  const zip = new JSZip();
  const zipData = await zip.loadAsync(zipFile);
  const entries = [];

  for (const [relativePath, zipEntry] of Object.entries(zipData.files)) {
    if (zipEntry.dir) continue;
    // macOS ve sistem meta dosyalarını yok say
    if (relativePath.startsWith('__MACOSX') || relativePath.split('/').pop().startsWith('._')) {
      continue;
    }

    const name = relativePath.split('/').pop();
    const ext = getFileExtension(name);
    const isConvertible =
      !BLOCKED_MEDIA_EXTENSIONS.has(ext) &&
      !BLOCKED_BINARY_EXTENSIONS.has(ext) &&
      (CODE_EXTENSIONS.has(ext) || ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'txt', 'md', 'json', 'log'].includes(ext));

    entries.push({
      path: relativePath,
      name,
      extension: ext,
      isConvertible,
      zipEntry,
    });
  }

  return {
    name: zipFile.name,
    file: zipFile,
    entries,
    files: entries,
    hasSupportedFiles: entries.some(e => e.isConvertible)
  };
}

/**
 * ZIP içinden seçilen dosyaları ayıklar ve File nesnelerine dönüştürür.
 */
export async function extractZipFiles(zipFile, selectedPaths) {
  const zip = new JSZip();
  const zipData = await zip.loadAsync(zipFile);
  const extractedFiles = [];

  for (const path of selectedPaths) {
    const entry = zipData.file(path);
    if (!entry) continue;

    const name = path.split('/').pop();
    // decode as text for code/txt
    const content = await entry.async('string');
    extractedFiles.push({
      name,
      path,
      content
    });
  }

  return extractedFiles;
}
