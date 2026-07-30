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

# Testing Guide

This covers testing locally, testing your deployed Render/Railway endpoint,
and running the same kind of promptfoo evaluation the course uses for
grading — so you can catch problems before you burn a submission attempt.

## 1. Smoke test — is it even up?

```bash
curl https://<your-app>.onrender.com/health
# → {"status":"ok"}

curl https://<your-app>.onrender.com/
# → {"status":"healthy","message":"FastAPI Data Analyst Application is running", ...}
```

If this hangs or 502s, the container is still building (first build installs
Chromium + JRE — can take several minutes) or crashed on startup — check the
platform's deploy logs before testing the real endpoint.

## 2. Basic end-to-end test

Create a minimal `question.txt`:

```
What is 2 + 2? Respond with a JSON array containing a single number.
```

```bash
curl "https://<your-app>.onrender.com/aianalyst/" \
  -F "questions.txt=@question.txt"
```

Expect something like `[4]` back within a few seconds. This exercises the
full pipeline (task breakdown → code gen → execution) without needing any
scraping or file parsing, so it's the fastest way to confirm the LLM keys
are valid and the self-fix loop works.

**Time it**, since the assignment's real constraint is speed, not just
correctness:

```bash
time curl "https://<your-app>.onrender.com/aianalyst/" -F "questions.txt=@question.txt"
```

## 3. Test with the actual sample task (Wikipedia scraping)

This is the worked example from the assignment brief — good for testing
scraping + DuckDB/pandas correlation + matplotlib scatterplot generation all
in one shot.

`question.txt`:

```
Scrape the list of highest grossing films from Wikipedia. It is at the URL:
https://en.wikipedia.org/wiki/List_of_highest-grossing_films

Answer the following questions and respond with a JSON array of strings containing the answer.

1. How many $2 bn movies were released before 2000?
2. Which is the earliest film that grossed over $1.5 bn?
3. What's the correlation between the Rank and Peak?
4. Draw a scatterplot of Rank and Peak along with a dotted red regression line through it. Return as a base-64 encoded data URI, "data:image/png;base64,iVBORw0KG..." under 100,000 bytes.
```

```bash
curl "https://<your-app>.onrender.com/aianalyst/" \
  -F "questions.txt=@question.txt" \
  --max-time 300
```

`--max-time 300` matches the grader's 5-minute-per-attempt window — if curl
times out here, your deployed instance will fail grading too, so this is the
single most important test to run before submitting.

Check the response:

```bash
curl ... | python3 -m json.tool   # pretty-print and confirm it's valid JSON
```

For the base64 image, sanity-check it decodes and is under the byte limit:

```bash
curl ... -o response.json
python3 -c "
import json, base64
data = json.load(open('response.json'))
uri = data[3]
b64 = uri.split(',', 1)[1]
raw = base64.b64decode(b64)
print(f'{len(raw)} bytes')
open('plot.png', 'wb').write(raw)
"
```

Then open `plot.png` and eyeball it: scatterplot of Rank vs Peak, dotted red
regression line, labeled axes.

## 4. Test with attachments (CSV / image / PDF)

```bash
curl "https://<your-app>.onrender.com/aianalyst/" \
  -F "questions.txt=@question.txt" \
  -F "data.csv=@data.csv" \
  -F "image.png=@image.png"
```

If you're testing PDF table extraction specifically, watch the platform
logs for `❌ Tabula extraction failed` — that means the JRE isn't present
in the running container (check you deployed via **Docker** runtime, not
Render's native Python runtime — see the main README's deployment section).

## 5. Concurrency test (mirrors how grading actually works)

> "Three simultaneous requests are sent to your API endpoint... Each request
> can retry up to 4 times... Each attempt has a 5-minute timeout."

Fire three requests at once and see whether they finish independently or
queue up behind each other:

```bash
for i in 1 2 3; do
  ( time curl -s "https://<your-app>.onrender.com/aianalyst/" \
      -F "questions.txt=@question.txt" -o "resp_$i.json" ) 2> "time_$i.txt" &
done
wait
for i in 1 2 3; do echo "--- request $i ---"; cat "time_$i.txt"; done
```

If request 3's time is roughly 3× request 1's time, your instance is
serializing requests (see **Known limitations** in the README — single
worker + blocking `subprocess.run`). If the third one blows past 5 minutes,
that's a real risk for grading and worth fixing (more workers, or move
`subprocess.run` to a thread executor) before submitting.

## 6. Local testing before you deploy at all

Fastest iteration loop — skip the Docker build entirely:

```bash
pip install -r requirements.txt
playwright install chromium
uvicorn app:app --reload --port 8000
```

```bash
curl "http://localhost:8000/aianalyst/" -F "questions.txt=@question.txt"
```

To test the exact production environment (including Tabula's JRE and
Playwright's Chromium with all system libs) before pushing:

```bash
docker build -t data-analyst-agent .
docker run --rm -p 8000:8000 --env-file .env data-analyst-agent
curl "http://localhost:8000/health"
```

If it works in this local Docker container, it'll work on Render/Railway
(same Dockerfile) — this is the highest-fidelity test available without an
actual deploy.

## 7. Promptfoo-style evaluation (what the grader actually runs)

The assignment scores you with [promptfoo](https://promptfoo.dev). You can
run the same style of eval yourself against your deployed endpoint before
the real grading pass. Install it and save this as `promptfooconfig.yaml`:

```yaml
description: "Data Analyst Agent - self-check eval"

providers:
  - id: https
    config:
      url: https://<your-app>.onrender.com/aianalyst/
      method: POST
      body: file://question.txt
      transformResponse: json

tests:
  - description: "Wikipedia films task"
    assert:
      - type: is-json
        value: { type: array, minItems: 4, maxItems: 4 }
        weight: 0
      - type: python
        weight: 1
        value: |
          import json
          data = json.loads(output)
          # answer 1 should be a small integer count
          print(isinstance(data[0], int))
      - type: python
        weight: 1
        value: |
          import json
          data = json.loads(output)
          print("titanic" in str(data[1]).lower())
      - type: python
        weight: 1
        value: |
          import json
          data = json.loads(output)
          print(abs(float(data[2])) <= 1.0)   # valid correlation coefficient
      - type: python
        weight: 1
        value: |
          import json, base64
          data = json.loads(output)
          uri = data[3]
          assert uri.startswith("data:image/")
          b64 = uri.split(",", 1)[1]
          raw = base64.b64decode(b64)
          print(len(raw) < 100_000)
```

```bash
npm install -g promptfoo
promptfoo eval -c promptfooconfig.yaml
promptfoo view   # opens a browser UI with pass/fail per assertion
```

This won't perfectly replicate the real (secret) test cases, but it
validates your JSON shape, value ranges, and image constraints — the
structural things most likely to zero out an otherwise-correct answer.

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Request hangs, no response, eventual timeout | Cold start on free tier, or serialized behind another request | Warm up the instance first; consider Starter plan |
| `502 Bad Gateway` immediately | Container crashed on boot | Check env vars are all set; check deploy logs |
| `❌ Tabula extraction failed` in logs | No JRE in the running container | Confirm the service is using the **Docker** runtime, not native Python |
| `❌ Playwright got blocked/access denied` | Site is blocking the stealth scraper | Expected occasionally — app should fall back to the httpx/bs4 path |
| Response is valid JSON but clearly a guess, not computed | All 3 self-fix attempts failed, hit the LLM fallback | Check logs for the actual execution error further up; the generated code is failing on something specific |
| Works with 1 request, fails with 3 concurrent | Single-worker blocking execution | See "Known limitations" in README |
| Image byte size over 100,000 | matplotlib default DPI/figure size too large | Lower `dpi=` and/or `figsize=` in the generated plotting code, or ask for a tighter prompt in `unified_code_instructions.txt` |



## License

MIT — see [LICENSE](./LICENSE).
