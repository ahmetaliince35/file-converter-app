FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# 1. OpenCV, FFmpeg ve C++ derleme bağımlılıkları
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2. Python 3.12 için temel araçlar ve PyTorch (Sadece CPU sürümü - RAM tasarrufu)
RUN pip install --upgrade pip setuptools wheel && \
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# 3. Kendi requirements dosyanızı kurun
COPY requirements.txt .
RUN pip install -r requirements.txt

# 4. Proje dosyalarını kopyala
COPY . .

RUN mkdir -p temp_storage

# 5. Render $PORT ile başlat
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]