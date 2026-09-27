import os
import io
import json
import zipfile
import numpy as np
from PIL import Image, ImageEnhance
import cv2
from pypdf import PdfReader, PdfWriter
import img2pdf
from pydub import AudioSegment
from pdf2docx import Converter

# EasyOCR için Singleton / Lazy Loader (RAM tasarrufu)
_ocr_reader = None

def get_ocr_reader():
    global _ocr_reader
    if _ocr_reader is None:
        import easyocr
        # gpu=False şart (Render CPU kullandığı için bellek taşmasını önler)
        _ocr_reader = easyocr.Reader(['tr', 'en'], gpu=False)
    return _ocr_reader


# 1. OCR METİN ÇIKARMA
def extract_text_local(image_path: str) -> str:
    reader = get_ocr_reader()
    results = reader.readtext(image_path, detail=0)
    return "\n".join(results)


# 2. GÖRSEL FORMAT DÖNÜŞTÜRME
def convert_image(in_path: str, out_path: str, target_format: str):
    target_format = target_format.lower().replace(".", "")
    if target_format == "jpg":
        target_format = "jpeg"

    with Image.open(in_path) as img:
        # RGBA -> RGB dönüşümü (JPEG/BMP şeffaflık desteklemez)
        if target_format in ["jpeg", "bmp"] and img.mode in ("RGBA", "LA", "P"):
            bg = Image.new("RGB", img.size, (255, 255, 255))
            if img.mode == "P":
                img = img.convert("RGBA")
            bg.paste(img, mask=img.split()[-1])
            bg.save(out_path, format=target_format.upper())
        elif target_format == "ico":
            img.save(out_path, format="ICO", sizes=[(256, 256), (128, 128), (64, 64), (32, 32)])
        else:
            img.save(out_path, format=target_format.upper())


# 3. SES DÖNÜŞTÜRME (FFmpeg tabanlı)
def convert_audio(in_path: str, out_path: str, target_format: str):
    target_format = target_format.lower().replace(".", "")
    sound = AudioSegment.from_file(in_path)
    sound.export(out_path, format=target_format)


# 4. GÖRSELLERDEN PDF OLUŞTURMA
def convert_images_to_pdf(img_paths: list, out_path: str):
    valid_images = []
    # img2pdf RGBA veya uyumsuz formatlarda patlamasın diye normalize et
    for p in img_paths:
        with Image.open(p) as img:
            if img.mode != "RGB":
                rgb_path = f"{p}_temp.jpg"
                img.convert("RGB").save(rgb_path, "JPEG")
                valid_images.append(rgb_path)
            else:
                valid_images.append(p)

    with open(out_path, "wb") as f:
        f.write(img2pdf.convert(valid_images))


# 5. PDF'DEN DOCX DÖNÜŞTÜRME
def convert_pdf_to_docx(in_path: str, out_path: str):
    cv = Converter(in_path)
    cv.convert(out_path, start=0, end=None)
    cv.close()


# 6. PDF BİRLEŞTİRME
def merge_pdfs(pdf_paths: list, out_path: str):
    writer = PdfWriter()
    for path in pdf_paths:
        reader = PdfReader(path)
        for page in reader.pages:
            writer.add_page(page)
    with open(out_path, "wb") as f:
        writer.write(f)


# 7. PDF SAYFA AYIKLAMA (1-tabanlı sayfa numaraları)
def extract_pdf_pages(contents: bytes, out_path: str, page_nums: list):
    reader = PdfReader(io.BytesIO(contents))
    writer = PdfWriter()
    total = len(reader.pages)

    for p in page_nums:
        idx = p - 1  # 1-indexed to 0-indexed
        if 0 <= idx < total:
            writer.add_page(reader.pages[idx])

    with open(out_path, "wb") as f:
        writer.write(f)


# 8. ZIP ARŞİVİ OLUŞTURMA
def create_archive(file_paths: list, out_path: str):
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        for f in file_paths:
            if os.path.exists(f):
                zipf.write(f, arcname=os.path.basename(f))


# 9. CAMSCANNER - KÖŞE TESPİTİ
def detect_document_corners(image_path: str) -> list:
    img = cv2.imread(image_path)
    if img is None:
        return []

    orig_h, orig_w = img.shape[:2]
    # Hızlı işlem için resmi ölçekle
    scale = 800.0 / max(orig_h, orig_w)
    resized = cv2.resize(img, (int(orig_w * scale), int(orig_h * scale)))

    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(blur, 50, 150)

    contours, _ = cv2.findContours(edged, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]

    for c in contours:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) == 4:
            # Orijinal çözünürlüğe geri dönüştür
            points = approx.reshape(4, 2) / scale
            return points.tolist()

    # Otomatik köşe bulunamazsa varsayılan olarak 4 köşeyi dön
    return [
        [0, 0],
        [orig_w, 0],
        [orig_w, orig_h],
        [0, orig_h]
    ]


# 10. CAMSCANNER - KÖŞE PERSPEKTİFİ & FİLTRELER
def order_points(pts):
    pts = np.array(pts, dtype="float32")
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]

    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def process_camscanner_interactive(in_path: str, out_path: str, points_str: str = None, filter_mode: str = "magic"):
    img = cv2.imread(in_path)
    if img is None:
        raise ValueError("Görsel yüklenemedi.")

    h, w = img.shape[:2]

    # Köşeler frontend'den JSON veya string olarak gelmişse uygula
    if points_str:
        try:
            pts = json.loads(points_str) if isinstance(points_str, str) else points_str
            rect = order_points(pts)
            (tl, tr, br, bl) = rect

            width_a = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
            width_b = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
            max_w = max(int(width_a), int(width_b))

            height_a = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
            height_b = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
            max_h = max(int(height_a), int(height_b))

            dst = np.array([
                [0, 0],
                [max_w - 1, 0],
                [max_w - 1, max_h - 1],
                [0, max_h - 1]
            ], dtype="float32")

            matrix = cv2.getPerspectiveTransform(rect, dst)
            img = cv2.warpPerspective(img, matrix, (max_w, max_h))
        except Exception:
            pass

    # Filtre İşleme
    filter_mode = (filter_mode or "original").lower().strip()

    if filter_mode == "magic":
        # Tipik CamScanner netleştirme (Adaptive Thresholding + Denoise)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        smooth = cv2.GaussianBlur(gray, (3, 3), 0)
        img = cv2.adaptiveThreshold(
            smooth, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 21, 10
        )
    elif filter_mode == "grayscale":
        img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    elif filter_mode == "bw":
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, img = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
    elif filter_mode == "enhanced":
        pil_img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        pil_img = ImageEnhance.Contrast(pil_img).enhance(1.5)
        pil_img = ImageEnhance.Sharpness(pil_img).enhance(1.8)
        img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)

    cv2.imwrite(out_path, img)