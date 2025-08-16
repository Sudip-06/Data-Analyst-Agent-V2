# nixpacks.toml
providers = ["python"]

[phases.setup]
# Keep whatever Nixpacks already picked and ADD these
nixPkgs = ["...", "python311", "python311Packages.pip", "curl", "wget", "gcc"]

[phases.install]
cmds = [
  "python -m pip install --upgrade pip",
  "pip install -r requirements.txt"
]

[start]
cmd = "uvicorn app:app --host 0.0.0.0 --port $PORT --workers 1"

