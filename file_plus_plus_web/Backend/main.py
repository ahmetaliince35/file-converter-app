import os
import shutil
import uuid
from typing import List
import base64
import io
import asyncio
import socket, random, string
import qrcode
import pypdfium2 as pdfium
from pypdf import PdfReader
from fastapi import APIRouter, Depends, BackgroundTasks, FastAPI, File, Form, HTTPException, UploadFile, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse

from converters import (
    convert_audio,
    convert_image,
    convert_images_to_pdf,
    convert_pdf_to_docx,
    create_archive,
    detect_document_corners,
    extract_pdf_pages,
    extract_text_local,
    merge_pdfs,
    process_camscanner_interactive,
)

SHARED_FILES = {}
SHARE_EXPIRATION_SECONDS = 900  # 15 dakika

app = FastAPI(title="File++ Super API", version="5.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

TEMP_DIR = "temp_storage"
os.makedirs(TEMP_DIR, exist_ok=True)
MAX_BATCH_SIZE = 1000 * 1024 * 1024  # 100 MB


def cleanup(path: str):
    """Dosya veya klasörü diskten temizler."""
    if path and os.path.exists(path):
        try:
            if os.path.isdir(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
        except Exception:
            pass


async def auto_delete_shared_file(share_id: str, file_path: str, delay_seconds: int = SHARE_EXPIRATION_SECONDS):
    """Belirtilen süre sonunda dosyayı diskten, kaydı ise bellekten siler."""
    await asyncio.sleep(delay_seconds)
    SHARED_FILES.pop(share_id, None)
    cleanup(file_path)


def get_base_url(request: Request) -> str:
    """Render domainini veya yerel adresi döner."""
    render_url = os.getenv("RENDER_EXTERNAL_URL")
    if render_url:
        return render_url.rstrip("/")
    return str(request.base_url).rstrip("/")


@app.get("/")
def health_check():
    return {"status": "active", "service": "File++ Engine v5.1"}


# 1. TOPLU DÖNÜŞTÜRÜCÜ & PDF BİRLEŞTİRME & ZIP
@app.post("/api/convert-batch")
async def convert_batch(
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    target_format: str = Form(...),
):
    if not files:
        raise HTTPException(400, "Hiç dosya yüklenmedi.")

    target_format = target_format.lower().strip()
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    saved_inputs = []
    total_size = 0

    for f in files:
        in_p = os.path.join(session_dir, f"in_{f.filename}")
        with open(in_p, "wb") as buf:
            while chunk := await f.read(1024 * 1024):
                total_size += len(chunk)
                if total_size > MAX_BATCH_SIZE:
                    cleanup(session_dir)
                    raise HTTPException(413, "100 MB boyutu aşıldı.")
                buf.write(chunk)
        saved_inputs.append((in_p, f.filename))

    if target_format == "pdf_merge":
        pdf_paths = [p[0] for p in saved_inputs if p[1].lower().endswith(".pdf")]
        if len(pdf_paths) < 2:
            cleanup(session_dir)
            raise HTTPException(400, "Birleştirmek için en az 2 PDF yükleyin.")
        out_pdf = os.path.join(session_dir, f"FilePlus_Merged_{session_id[:6]}.pdf")
        merge_pdfs(pdf_paths, out_pdf)
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(out_pdf, filename="FilePlus_Merged.pdf", media_type="application/pdf")

    if target_format == "zip":
        out_zip = os.path.join(session_dir, f"FilePlus_Archive_{session_id[:6]}.zip")
        create_archive([p[0] for p in saved_inputs], out_zip)
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(out_zip, filename="FilePlus_Archive.zip")

    converted_files = []
    image_exts = ["png", "jpg", "jpeg", "webp", "ico", "bmp"]
    audio_exts = ["mp3", "wav", "ogg", "m4a", "flac"]

    for in_p, orig_name in saved_inputs:
        base, ext = os.path.splitext(orig_name)
        ext = ext.lower().replace(".", "")
        out_p = os.path.join(session_dir, f"{base}_converted.{target_format}")

        try:
            if ext in image_exts and target_format in image_exts:
                convert_image(in_p, out_p, target_format)
                converted_files.append(out_p)
            elif ext == "pdf" and target_format == "docx":
                convert_pdf_to_docx(in_p, out_p)
                converted_files.append(out_p)
            elif ext in audio_exts and target_format in audio_exts:
                convert_audio(in_p, out_p, target_format)
                converted_files.append(out_p)
        except Exception:
            continue

    if not converted_files:
        cleanup(session_dir)
        raise HTTPException(400, "Desteklenmeyen dosya formatı eşleşmesi.")

    if len(converted_files) == 1:
        sp = converted_files[0]
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(sp, filename=os.path.basename(sp))
    else:
        zip_p = os.path.join(session_dir, f"FilePlus_Bundle_{session_id[:6]}.zip")
        create_archive(converted_files, zip_p)
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(zip_p, filename="FilePlus_Bundle.zip")


# 2. GÖRSELLERDEN PDF OLUŞTURMA
@app.post("/api/images-to-pdf")
async def api_images_to_pdf(
    background_tasks: BackgroundTasks, files: List[UploadFile] = File(...)
):
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    img_paths = []
    for f in files:
        p = os.path.join(session_dir, f.filename)
        with open(p, "wb") as b:
            b.write(await f.read())
        img_paths.append(p)

    out_pdf = os.path.join(session_dir, "FilePlus_Gallery.pdf")
    try:
        convert_images_to_pdf(img_paths, out_pdf)
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(out_pdf, filename="FilePlus_Gallery.pdf")
    except Exception as e:
        cleanup(session_dir)
        raise HTTPException(500, f"PDF yapma hatası: {str(e)}")


# 3. PDF SAYFA AYIKLAMA & THUMBNAILS
@app.post("/api/pdf-extract")
async def api_pdf_extract(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    pages: str = Form(...),
):
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    contents = await file.read()
    if not contents:
        raise HTTPException(400, "Yüklenen PDF boş veya okunamadı.")

    out_p = os.path.join(session_dir, f"Extracted_{file.filename}")

    try:
        page_nums = [int(p.strip()) for p in str(pages).split(",") if p.strip().isdigit()]
        if not page_nums:
            raise HTTPException(400, "Geçersiz sayfa numarası.")

        extract_pdf_pages(contents, out_p, page_nums)

        if not os.path.exists(out_p):
            raise HTTPException(500, "Ayıklanan PDF oluşturulamadı.")

        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(out_p, filename=f"Extracted_{file.filename}", media_type="application/pdf")
    except Exception as e:
        cleanup(session_dir)
        raise HTTPException(500, f"Sayfa ayıklama hatası: {str(e)}")


@app.post("/api/pdf-thumbnails")
async def get_pdf_thumbnails(file: UploadFile = File(...)):
    contents = await file.read()
    if not contents:
        raise HTTPException(400, "Dosya boş.")

    try:
        pdf = pdfium.PdfDocument(contents)
        total_pages = len(pdf)
        thumbnails = []

        for i in range(total_pages):
            page = pdf[i]
            image = page.render(scale=1.0).to_pil()

            buf = io.BytesIO()
            image.save(buf, format="JPEG", quality=75)
            b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

            thumbnails.append({
                "page_number": i + 1,
                "image": f"data:image/jpeg;base64,{b64}",
            })

        return {"total_pages": total_pages, "thumbnails": thumbnails}
    except Exception as e:
        raise HTTPException(500, f"Önizleme oluşturulamadı: {str(e)}")


# 4. CAMSCANNER
@app.post("/api/camscanner/detect-corners")
async def api_camscanner_detect(
    background_tasks: BackgroundTasks, file: UploadFile = File(...)
):
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    in_p = os.path.join(session_dir, file.filename)
    with open(in_p, "wb") as b:
        b.write(await file.read())

    try:
        points = detect_document_corners(in_p)
        background_tasks.add_task(cleanup, session_dir)
        return {"points": points}
    except Exception as e:
        cleanup(session_dir)
        raise HTTPException(500, f"Köşe tespiti hatası: {str(e)}")


@app.post("/api/camscanner")
async def api_camscanner(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    points: str = Form(None),
    filter_mode: str = Form("magic"),
):
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    in_p = os.path.join(session_dir, file.filename)
    out_p = os.path.join(session_dir, f"Scanned_{file.filename}")

    with open(in_p, "wb") as b:
        b.write(await file.read())

    try:
        process_camscanner_interactive(in_p, out_p, points, filter_mode)
        background_tasks.add_task(cleanup, session_dir)
        return FileResponse(out_p, filename=f"Scanned_{file.filename}")
    except Exception as e:
        cleanup(session_dir)
        raise HTTPException(500, f"Tarama hatası: {str(e)}")


# 5. OCR & BİLGİ
@app.post("/api/ocr")
async def api_ocr(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    session_id = str(uuid.uuid4())
    session_dir = os.path.join(TEMP_DIR, session_id)
    os.makedirs(session_dir, exist_ok=True)

    in_p = os.path.join(session_dir, file.filename)
    with open(in_p, "wb") as b:
        b.write(await file.read())

    try:
        text = extract_text_local(in_p)
        background_tasks.add_task(cleanup, session_dir)
        return {"text": text}
    except Exception as e:
        cleanup(session_dir)
        raise HTTPException(500, f"OCR Hatası: {str(e)}")


@app.post("/api/pdf-info")
async def get_pdf_info(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(400, "Dosya boş.")
        reader = PdfReader(io.BytesIO(contents))
        return {"total_pages": len(reader.pages)}
    except Exception as e:
        raise HTTPException(500, f"PDF okuma hatası: {str(e)}")


# 6. PAYLAŞIM PORTALI (RENDER UYUMLU + OTOMATİK SİLME)
@app.post("/api/share/create")
async def create_share_link(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    share_id = "".join(random.choices(string.ascii_letters + string.digits, k=8))
    pin = f"{random.randint(1000, 9999)}"

    save_path = os.path.join(TEMP_DIR, f"share_{share_id}_{file.filename}")
    with open(save_path, "wb") as f:
        f.write(await file.read())

    SHARED_FILES[share_id] = {
        "file_path": save_path,
        "filename": file.filename,
        "pin": pin,
    }

    # 15 dakika (900 saniye) sonra hem diskten hem bellekten temizle
    background_tasks.add_task(
        auto_delete_shared_file, share_id, save_path, SHARE_EXPIRATION_SECONDS
    )

    base_url = get_base_url(request)
    share_url = f"{base_url}/share/{share_id}"

    qr = qrcode.QRCode(box_size=6, border=2)
    qr.add_data(share_url)
    qr_img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    qr_img.save(buf, format="PNG")
    buf.seek(0)
    qr_base64 = f"data:image/png;base64,{base64.b64encode(buf.getvalue()).decode('utf-8')}"

    return {
        "share_id": share_id,
        "share_url": share_url,
        "pin": pin,
        "qr_code": qr_base64,
        "filename": file.filename,
        "expires_in_seconds": SHARE_EXPIRATION_SECONDS,
    }


@app.get("/share/{share_id}", response_class=HTMLResponse)
async def serve_share_page(share_id: str):
    if share_id not in SHARED_FILES:
        return HTMLResponse(
            """
            <!DOCTYPE html>
            <html lang="tr">
            <head><meta charset="UTF-8"><title>Süresi Doldu</title><script src="https://cdn.tailwindcss.com"></script></head>
            <body class="bg-slate-950 text-slate-100 flex items-center justify-center min-h-screen p-4 font-sans">
                <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl max-w-sm w-full text-center">
                    <h2 class="text-rose-400 font-bold text-lg mb-2">Bağlantı Geçersiz</h2>
                    <p class="text-xs text-slate-400">Bu dosyanın indirme süresi (15 dk) dolmuş veya dosya kaldırılmış.</p>
                </div>
            </body>
            </html>
            """,
            status_code=404,
        )

    doc = SHARED_FILES[share_id]
    return f"""
    <!DOCTYPE html>
    <html lang="tr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>File++ Paylaşım Portalı</title>
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-slate-950 text-slate-100 flex items-center justify-center min-h-screen p-4 font-sans">
        <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl max-w-sm w-full shadow-2xl flex flex-col items-center gap-4 text-center">
            <div class="bg-sky-500/10 text-sky-400 p-3 rounded-full border border-sky-500/20">
                <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
            </div>
            <div>
                <h1 class="text-base font-bold text-white truncate max-w-[240px]">{doc['filename']}</h1>
                <p class="text-xs text-slate-400 mt-1">İndirmek için gönderici ekranındaki 4 haneli PIN kodunu girin.</p>
            </div>
            <form action="/share/{share_id}/download" method="POST" class="w-full flex flex-col gap-3">
                <input type="password" maxlength="4" name="pin" placeholder="PIN (4 Hane)" required autofocus
                       class="text-center tracking-widest text-lg font-mono bg-slate-950 border border-slate-700 rounded-xl px-4 py-2.5 text-white outline-none focus:border-sky-400" />
                <button type="submit" class="bg-sky-500 hover:bg-sky-400 text-slate-950 font-bold py-2.5 rounded-xl text-sm transition">
                    Doğrula & Dosyayı İndir
                </button>
            </form>
        </div>
    </body>
    </html>
    """


@app.post("/share/{share_id}/download")
async def verify_and_download(share_id: str, pin: str = Form(...)):
    if share_id not in SHARED_FILES:
        raise HTTPException(404, "Dosya bulunamadı veya süresi doldu.")

    doc = SHARED_FILES[share_id]
    if doc["pin"] != pin.strip():
        return HTMLResponse(
            "<script>alert('Hatalı PIN!'); window.history.back();</script>",
            status_code=401,
        )

    return FileResponse(doc["file_path"], filename=doc["filename"])