# syntax=docker/dockerfile:1.6
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000 \
    MPLCONFIGDIR=/tmp/matplotlib \
    MPLBACKEND=Agg

WORKDIR /app

# System deps:
# - default-jre-headless for tabula-py
# - Chromium runtime libs for Playwright
# - fonts so headless Chromium can render text
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates default-jre-headless \
    libnss3 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxi6 libxtst6 libcups2 libxrandr2 libgtk-3-0 libgbm1 libpango-1.0-0 \
    libasound2 libatk1.0-0 libatk-bridge2.0-0 libdrm2 libxfixes3 libxkbcommon0 \
    libegl1 libxshmfence1 libglib2.0-0 unzip \
    fonts-unifont fonts-ubuntu fonts-liberation fonts-dejavu-core \
  && rm -rf /var/lib/apt/lists/*

# Install Python deps first (better caching)
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Download Playwright's Chromium (no OS deps script)
RUN python -m playwright install chromium

# Copy the app
COPY . .

EXPOSE 8000

# Healthcheck (your app serves /health)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

# Start FastAPI (change module:var if not app:app)
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "${PORT}", "--workers", "1", "--log-level", "warning", "--proxy-headers"]
