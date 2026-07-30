# Data Analyst FastAPI Application

A powerful FastAPI application for data analysis with multiple LLM integrations, web scraping capabilities, and OCR functionality.

## Project Statement : https://tds.s-anand.net/project-data-analyst-agent/

## Features

- **Multiple LLM Support**: Gemini 2.0 Flash, Gemini 2.5 Pro, GPT-4o Mini, Horizon Beta
- **Web Scraping**: Playwright-based scraping with stealth capabilities
- **OCR Processing**: Image text extraction using OCR.space API
- **Data Analysis**: Pandas, NumPy, DuckDB for data processing
- **File Processing**: Support for CSV, Excel, PDF, images, and archives

## Quick Start

### Local Development

1. Clone the repository:
```bash
git clone <your-repo-url>
cd dataanalyst-main
```

2. Create virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
playwright install
```

4. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys
```

5. Run the application:
```bash
python app.py
```

The API will be available at `http://localhost:8000` with docs at `http://localhost:8000/docs`

### Required API Keys

Create a `.env` file with the following keys:

```env
# Essential APIs
gemini_api=your_google_gemini_api_key_here
gemini_api_2=your_second_gemini_api_key_here
API_KEY=your_openai_compatible_api_key_here
horizon_api=your_openrouter_api_key_here

# Optional APIs
OCR_API_KEY=your_ocr_space_api_key_here
grok_api=your_grok_api_key_here
grok_fix_api=your_grok_fix_api_key_here
```

### How to get API Keys

1. **Google Gemini**: [Google AI Studio](https://makersuite.google.com/app/apikey)
2. **OpenAI**: [OpenAI Platform](https://platform.openai.com/api-keys)
3. **OpenRouter**: [OpenRouter](https://openrouter.ai/)
4. **OCR.space**: [OCR.space](https://ocr.space/ocrapi)

## Railway Deployment

This app is configured for Railway deployment:

1. **Connect to Railway**:
   - Go to [Railway](https://railway.app)
   - Connect your GitHub repository
   - Select this repository

2. **Set Environment Variables**:
   - Add all required API keys in Railway dashboard
   - Railway will automatically detect the Python app

3. **Deploy**:
   - Railway will automatically build and deploy
   - Your app will be available at the generated Railway URL

## Models Used

- **Gemini 2.0 Flash**: Fast data extraction and task breaking
- **Gemini 2.5 Pro**: Advanced code generation and fixing
- **GPT-4o Mini**: Cost-effective text generation
- **Horizon Beta**: Alternative model via OpenRouter

## API Endpoints

- `GET /`: Health check
- `POST /analyze`: Main data analysis endpoint
- `POST /upload`: File upload and processing
- `GET /docs`: Interactive API documentation

## Tech Stack

- **FastAPI**: Modern web framework
- **Playwright**: Web scraping
- **Pandas/NumPy**: Data processing
- **DuckDB**: Fast analytical database
- **Matplotlib/Seaborn**: Data visualization
- **Multiple LLMs**: AI-powered analysis

# Data Analyst Agent

An LLM-powered API that takes a plain-English data analysis task (plus optional
attachments — CSV, PDF, images, HTML, JSON, archives) and returns answers as
JSON, including base64-encoded charts, within a 3–5 minute window.

Built for the [TDS Project 2: Data Analyst Agent](https://tds.s-anand.net/project-data-analyst-agent/)
assignment.

> **Deployment note:** this app is hosted as a persistent Docker container, not
> a serverless function. It depends on a headless Chromium browser (Playwright)
> and a JRE (tabula-py), and requests can legitimately run for minutes at a
> time — none of which serverless platforms like Vercel support. **Render**
> and **Railway** are the supported targets; see [Deployment](#deployment)
> below.

---

## How it works

```
questions.txt + attachments
        │
        ▼
1. Ingest & classify files        (app.py)
   csv / html / json / pdf / image / tar / zip → parsed into a data summary
        │
        ▼
2. Task breakdown                 (prompts/task_breaker.txt via Gemini 2.0 Flash)
   turns the free-text question into 3–5 concrete, programmable steps
        │
        ▼
3. Code generation                (prompts/unified_code_instructions.txt)
   an LLM writes a self-contained Python script that reads the parsed data,
   computes the answers, and prints a JSON array/object to stdout
        │
        ▼
4. Execution                      subprocess.run(["python", script], timeout=...)
        │
        ├─ success + valid JSON ──────────────────────────► return to caller
        │
        └─ failure ──► 5. Self-fix loop (up to 3 attempts)
                        error + code + data summary sent back to Gemini 2.5 Pro,
                        which patches the script; re-executed each time
                              │
                              ├─ success ──────────────────► return to caller
                              └─ still failing ──► 6. Last-resort fallback:
                                                    ask an LLM to produce its
                                                    best-guess JSON answer
                                                    directly (no guarantee of
                                                    correctness, but guarantees
                                                    *a* valid JSON response)
```

This "generate → execute → self-heal" loop is why the app needs a real process
it can shell out from — not a stateless serverless function.

## Features

- **Multi-LLM pipeline**: Gemini 2.0 Flash (task breakdown, fast extraction),
  Gemini 2.5 Pro (code generation/fixing), GPT-4o-mini via aipipe (fallback
  text generation), Horizon Beta via OpenRouter (alternate model)
- **Web scraping**: `httpx`/`BeautifulSoup` for static pages, with a
  Playwright + `playwright-stealth` fallback for JS-rendered or bot-guarded
  pages
- **File ingestion**: CSV, HTML, JSON, PDF (via `tabula-py`, needs a JRE),
  images (OCR via OCR.space), and `.zip`/`.tar`/`.tar.gz`/`.jar` archives
- **Analysis**: pandas, NumPy, DuckDB (including remote Parquet over
  `httpfs`, e.g. S3-hosted datasets)
- **Visualization**: matplotlib/seaborn charts returned as base64 data URIs
- **Self-healing code execution**: generated analysis code that fails is
  automatically diagnosed and re-written, up to 3 times, before falling back
  to a direct LLM-guessed answer so the endpoint always returns *something*
  valid within the time budget

## Repo structure

```
app.py                              FastAPI app — routes, file handling, code exec, self-fix loop
data_scrape.py                      Scraping (httpx/bs4 + Playwright stealth fallback)
prompts/task_breaker.txt            Prompt: question → concrete steps
prompts/unified_code_instructions.txt  Prompt: steps + data summary → Python code
Dockerfile                          Full system image (JRE, Chromium libs, fonts, Python deps)
render.yaml                         Render Blueprint (Docker runtime)
railway.toml                        Railway config (Docker runtime)
Procfile / runtime.txt / .buildpacks  Heroku-style config (kept for reference; unused by Render/Railway)
requirements.txt                    Python dependencies
TESTING.md                          Full testing guide (see below)
```

## Environment variables

| Variable        | Required | Used for                                             | Get it from |
|------------------|:--------:|-------------------------------------------------------|-------------|
| `gemini_api`     | ✅       | Task breakdown, primary Gemini calls                  | [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `gemini_api_2`   | ✅       | Second Gemini key (rotated in when the first is rate-limited) | Google AI Studio |
| `API_KEY`        | ✅       | OpenAI-compatible completions (via aipipe.org)         | [aipipe.org](https://aipipe.org) or OpenAI |
| `horizon_api`    | ✅       | Horizon Beta model via OpenRouter                      | [OpenRouter](https://openrouter.ai/keys) |
| `OCR_API_KEY`    | Optional | OCR text extraction from images                        | [OCR.space](https://ocr.space/ocrapi) |
| `grok_api`       | Optional | Not currently wired up — safe to leave blank           | — |
| `grok_fix_api`   | Optional | Not currently wired up — safe to leave blank           | — |

Copy `.env.example` to `.env` for local dev. On Render/Railway these are set
in the dashboard, never committed.

---

## Deployment

### Option 1 — Render (recommended)

Render runs your Dockerfile as-is on a persistent instance, which is exactly
what this app needs (real Chromium, real JRE, no execution-time ceiling from
the platform itself).

**Via Blueprint (fastest — uses the included `render.yaml`):**

1. Push this repo to GitHub (public, MIT `LICENSE` already included ✅).
2. In the [Render Dashboard](https://dashboard.render.com), click
   **New → Blueprint**, and connect the repo.
3. Render reads `render.yaml` and shows you a service named
   `data-analyst-agent` using `runtime: docker` — confirm it's picking up
   `Dockerfile` from the repo root, then click **Deploy Blueprint**.
4. Once created, go to the service → **Environment** and fill in the five
   `sync: false` variables from the table above (Render prompts for these
   automatically the first time since the blueprint marks them as secrets).
5. Wait for the build to finish (installing Chromium + JRE adds a few minutes
   to the first build). Watch the logs for `Uvicorn running on
   http://0.0.0.0:$PORT`.
6. Your endpoint is `https://<service-name>.onrender.com/aianalyst/` — note
   the **`/aianalyst/`** path, the base URL alone will just hit the health
   check.

**Via dashboard manually (if you skip the Blueprint):** New → Web Service →
connect repo → **Environment: Docker** (not "Python" — this is the one
setting that matters most) → leave build/start commands blank so it uses the
Dockerfile's `CMD` → set the same env vars → **Health Check Path**:
`/health`.

**Plan choice:** Free tier (512MB RAM / 0.1 CPU) will run this, but it's
tight — Chromium, a JVM, and pandas/DuckDB competing for 512MB can OOM under
load, and free services spin down after 15 minutes idle (30–60s cold start on
the next request, eating into your time budget). For grading — where three
simultaneous requests get fired at your endpoint — the **Starter plan
($7/mo)** is worth it for the extra headroom and no spin-down. At minimum,
send a warm-up request before the actual grading window starts.

### Option 2 — Railway (fallback)

Railway also builds straight from `Dockerfile` (see `railway.toml`) and
tends to have a faster cold start than Render's free tier.

1. Push to GitHub.
2. [Railway Dashboard](https://railway.app) → **New Project → Deploy from
   GitHub repo** → select this repo.
3. Railway detects `railway.toml` → `dockerfilePath = "Dockerfile"`
   automatically.
4. Go to **Variables** and add the five required env vars.
5. Go to **Settings → Networking → Generate Domain** to get a public URL.
6. Your endpoint is `https://<your-app>.up.railway.app/aianalyst/`.

Railway's free trial is credit-based (not a permanently-free tier like
Render), so check your remaining credit before a grading run.

### Why not Vercel

Vercel Python functions are stateless serverless invocations with a hard
execution-time ceiling (a few minutes at best, on paid plans) and a
read-only filesystem outside `/tmp` — you can't bundle or launch a real
Chromium browser, and there's no JRE for `tabula-py`. This app's
generate→execute→self-heal loop plus scraping needs a real long-running
process, which is what Render/Railway give you.

---

## Local development

```bash
git clone <your-repo-url>
cd Data-Analyst-Agent-V2-main
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
playwright install chromium
cp .env.example .env   # then fill in your keys
python app.py          # or: uvicorn app:app --reload
```

Runs at `http://localhost:8000`, interactive docs at `http://localhost:8000/docs`.

Note: `tabula-py` needs a JRE on your machine too (`sudo apt install
default-jre-headless` / `brew install openjdk`) if you want to test PDF table
extraction locally.

## API reference

```
POST /aianalyst/
Content-Type: multipart/form-data

Fields:
  questions.txt   (always present) — the task description
  <anything>      (0 or more) — .csv, .json, .html, .pdf, .png/.jpg/etc,
                  .zip/.tar/.tar.gz/.jar — categorized by file extension,
                  field name doesn't matter
```

Response: `application/json`, shape depends on what the question asked for —
typically a JSON array of answers (in order) or a JSON object keyed by
question, per the task's instructions. Charts are returned as
`"data:image/png;base64,..."` strings inline in the array/object.

```
GET /health   → {"status": "ok"}
GET /         → basic status + endpoint listing
GET /docs     → Swagger UI
```

See **[TESTING.md](./TESTING.md)** for curl examples, sample payloads, and a
pre-submission checklist.

## Known limitations

- **Single worker, blocking execution**: the Dockerfile runs `uvicorn
  --workers 1`, and the code-execution step uses a blocking
  `subprocess.run(...)` inside an `async def` route. That means concurrent
  requests to the same instance are effectively serialized rather than
  processed in parallel. The grading process sends **three simultaneous
  requests** — on a single instance these will queue behind each other, so
  make sure your per-request time (including any fix-retry attempts) leaves
  enough budget for the last request in the queue to still finish in time.
  Options if this bites you: bump `--workers` (each worker gets its own
  Chromium/JRE overhead, so check RAM), or move the blocking `subprocess.run`
  calls onto a thread pool (`run_in_executor`) so uvicorn's event loop can
  interleave requests.
- **Cold starts**: free-tier Render/Railway instances sleep when idle. A
  warm-up ping before grading avoids losing 30–60s of your budget on the
  first request.
- **Fallback answer is a guess, not a computation**: if all 3 fix attempts
  fail, the app asks an LLM to fabricate a plausible-looking JSON answer
  rather than a computed one — it guarantees a well-formed response, not a
  correct one.

## Tech stack

FastAPI · Playwright + playwright-stealth · pandas / NumPy · DuckDB (+
httpfs/parquet) · matplotlib / seaborn · tabula-py · BeautifulSoup4 · Gemini
2.0 Flash & 2.5 Pro · GPT-4o-mini (via aipipe) · Horizon Beta (via
OpenRouter) · OCR.space

## License

MIT — see [LICENSE](./LICENSE).
