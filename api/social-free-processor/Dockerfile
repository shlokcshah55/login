FROM python:3.11-slim

# System dependencies:
#   tesseract-ocr — self-hosted OCR engine (frames never leave our infra)
#   ffmpeg        — frame extraction from video stream via pipe
#   yt-dlp        — resolve CDN video URL without downloading (frame OCR fallback only)
RUN apt-get update && apt-get install -y --no-install-recommends \
        tesseract-ocr \
        tesseract-ocr-eng \
        ffmpeg \
        curl \
    && pip install --no-cache-dir yt-dlp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT=8080
# RAM-backed temp: yt-dlp subtitle files (text-only) never touch persistent disk
ENV TMPDIR=/dev/shm
EXPOSE 8080

# 4 threads per worker: OCR + ffmpeg stages are I/O-heavy so threads beat processes here.
# Timeout 600s: frame OCR can take up to 60s on slow CDN streams.
CMD exec gunicorn --bind :$PORT --workers 2 --threads 4 --timeout 600 main:app
