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
    build-essential curl ca-certificates default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps first for better caching
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Install Playwright browser + its OS deps (Chromium)
# (Needed if your code uses playwright)
RUN python -m playwright install --with-deps chromium

# Copy the rest of the app
COPY . .

EXPOSE 8000

# Healthcheck (your app should serve 200 at /health)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

# Change app:app if your module/variable differs (e.g., main:app)
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "${PORT}", "--workers", "1", "--log-level", "warning", "--proxy-headers"]
