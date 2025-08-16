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

# System deps: build tools, curl, and Java (for tabula-py)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first (layer cache-friendly)
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Install Playwright browser + its OS deps (Chromium)
RUN python -m playwright install --with-deps chromium

# Copy the rest of the code
COPY . .

EXPOSE 8000

# Container-level healthcheck; your app already serves /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

# IMPORTANT: if your entry file isn't app.py, change module:variable below
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "${PORT}", "--workers", "1", "--log-level", "warning", "--proxy-headers"]
