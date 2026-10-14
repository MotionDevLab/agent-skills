#!/usr/bin/env python3
"""laya-setup.py -- Laya model auto-download and runtime bootstrap.

ASCII-only source by design (repo tooling must parse under Windows PowerShell 5.1).

Usage:
  python scripts/laya-setup.py --check                report backend + weight status as JSON
  python scripts/laya-setup.py --download              fetch pinned weights (resumable, verified)
  python scripts/laya-setup.py --verify                run one tiny inference, exit nonzero on failure
  python scripts/laya-setup.py --download --verify     full bootstrap (what installers call)

Config: skills/laya/config.example.json by default, override with --config PATH
or LAYA_CONFIG. Weights dir: <repo>/weights by default, override with LAYA_WEIGHTS_DIR.
Python 3.10+. Third-party deps only: requests, tqdm (see requirements-laya.txt).
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CONFIG = os.path.join(REPO_ROOT, "skills", "laya", "config.example.json")
DEFAULT_WEIGHTS = os.path.join(REPO_ROOT, "weights")

VERIFY_PROMPT = (
    "Classify this message as exactly one word: refund, bug, howto, or other. "
    "Reply with only that word. Message: My order never arrived and I want my money back."
)
VERIFY_ACCEPT = {"refund", "bug", "howto", "other"}


def load_config(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def which(name):
    return shutil.which(name)


def ollama_models():
    """Return set of pulled ollama model names, or None if ollama is absent."""
    if not which("ollama"):
        return None
    try:
        out = subprocess.run(
            ["ollama", "list"], capture_output=True, text=True, timeout=30
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    names = set()
    for line in out.stdout.splitlines()[1:]:
        parts = line.split()
        if parts:
            names.add(parts[0])
    return names


def llamacpp_binary():
    for name in ("llama-cli", "llama-run", "main"):
        path = which(name)
        if path:
            return path
    return None


def transformers_available():
    try:
        __import__("transformers")
        __import__("torch")
        return True
    except ImportError:
        return False


def detect_backend(config, weights_dir):
    """Return (backend, detail). Order: ollama -> llama.cpp -> transformers-cpu -> none."""
    ollama_id = config.get("ollama_model", "")
    models = ollama_models()
    if models is not None:
        if ollama_id and ollama_id in models:
            return "ollama", "model pulled: %s" % ollama_id
        return "ollama", "ollama present, model %s not pulled yet" % ollama_id
    gguf_name = config.get("gguf_file", "")
    if gguf_name and os.path.exists(os.path.join(weights_dir, gguf_name)):
        if llamacpp_binary():
            return "llama.cpp", "weights present: %s" % gguf_name
        return "llama.cpp", "weights present but no llama.cpp binary found"
    if transformers_available():
        return "transformers-cpu", "torch+transformers installed"
    return "none", "no backend available (install Ollama or download GGUF weights)"


def model_present(config, weights_dir):
    ollama_id = config.get("ollama_model", "")
    models = ollama_models()
    if models is not None and ollama_id in models:
        return True
    gguf_name = config.get("gguf_file", "")
    if gguf_name and os.path.exists(os.path.join(weights_dir, gguf_name)):
        return True
    return False


def cmd_check(config, weights_dir):
    backend, detail = detect_backend(config, weights_dir)
    status = {
        "backend": backend,
        "detail": detail,
        "model_present": model_present(config, weights_dir),
        "model_id": config.get("model_id", ""),
        "weights_dir": weights_dir,
    }
    print(json.dumps(status))
    return 0


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_file(url, dest, expected_sha256=None):
    """Resumable download with optional sha256 check. Skips if already valid."""
    try:
        import requests
    except ImportError:
        print("ERROR: requests is required for download (pip install -r scripts/requirements-laya.txt)",
              file=sys.stderr)
        return 1
    try:
        from tqdm import tqdm
        progress = True
    except ImportError:
        progress = False

    if os.path.exists(dest) and expected_sha256:
        if sha256_of(dest).lower() == expected_sha256.lower():
            print("already present and valid: %s" % dest)
            return 0
        print("checksum mismatch, re-downloading: %s" % dest)

    existing = os.path.getsize(dest) if os.path.exists(dest) else 0
    headers = {"Range": "bytes=%d-" % existing} if existing else {}
    try:
        resp = requests.get(url, headers=headers, stream=True, timeout=60)
    except OSError as exc:
        print("ERROR: download failed for %s: %s" % (url, exc), file=sys.stderr)
        print("Mirror/fallback: check config.example.json gguf_mirrors or pull via Ollama instead.",
              file=sys.stderr)
        return 1
    if resp.status_code == 416:
        print("already complete: %s" % dest)
        return 0
    if resp.status_code not in (200, 206):
        print("ERROR: HTTP %s for %s" % (resp.status_code, url), file=sys.stderr)
        return 1
    total = int(resp.headers.get("content-length", 0)) + (existing if resp.status_code == 206 else 0)
    mode = "ab" if resp.status_code == 206 else "wb"
    bar = tqdm(total=total, initial=(existing if mode == "ab" else 0),
               unit="B", unit_scale=True, desc=os.path.basename(dest)) if progress else None
    try:
        with open(dest, mode) as fh:
            for chunk in resp.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    fh.write(chunk)
                    if bar:
                        bar.update(len(chunk))
    finally:
        if bar:
            bar.close()
    if expected_sha256:
        actual = sha256_of(dest)
        if actual.lower() != expected_sha256.lower():
            print("ERROR: checksum mismatch for %s (got %s)" % (dest, actual), file=sys.stderr)
            return 1
    print("downloaded: %s" % dest)
    return 0


def cmd_download(config, weights_dir):
    os.makedirs(weights_dir, exist_ok=True)
    ollama_id = config.get("ollama_model", "")
    if which("ollama") and ollama_id:
        print("pulling via ollama: %s" % ollama_id)
        proc = subprocess.run(["ollama", "pull", ollama_id])
        if proc.returncode == 0:
            print("ollama pull OK: %s" % ollama_id)
            return 0
        print("WARNING: ollama pull failed, falling back to direct GGUF download.",
              file=sys.stderr)
    url = config.get("gguf_url", "")
    if not url:
        print("ERROR: no gguf_url in config and ollama pull failed.", file=sys.stderr)
        return 1
    dest = os.path.join(weights_dir, config.get("gguf_file", "laya-model.gguf"))
    return download_file(url, dest, config.get("gguf_sha256") or None)


def run_ollama(model, prompt):
    proc = subprocess.run(["ollama", "run", model, prompt],
                          capture_output=True, text=True, timeout=300)
    if proc.returncode != 0:
        return None
    return proc.stdout.strip().lower()


def run_llamacpp(binary, weights_path, prompt):
    proc = subprocess.run(
        [binary, "-m", weights_path, "-p", prompt, "-n", "8", "--temp", "0.0"],
        capture_output=True, text=True, timeout=600)
    if proc.returncode != 0:
        return None
    return proc.stdout.strip().lower()


def cmd_verify(config, weights_dir):
    backend, _ = detect_backend(config, weights_dir)
    answer = None
    if backend == "ollama":
        answer = run_ollama(config.get("ollama_model", ""), VERIFY_PROMPT)
    elif backend == "llama.cpp":
        answer = run_llamacpp(llamacpp_binary(),
                              os.path.join(weights_dir, config.get("gguf_file", "")),
                              VERIFY_PROMPT)
    else:
        print("ERROR: no runnable backend for verify (need ollama model or GGUF weights).",
              file=sys.stderr)
        return 1
    if answer is None:
        print("ERROR: inference process failed.", file=sys.stderr)
        return 1
    first_word = answer.split()[0].strip(".,\"'") if answer.split() else ""
    if first_word in VERIFY_ACCEPT:
        print("verify OK (backend=%s, answer=%s)" % (backend, first_word))
        return 0
    print("ERROR: unexpected verify answer: %r" % answer, file=sys.stderr)
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description="Laya model bootstrap")
    parser.add_argument("--config", default=os.environ.get("LAYA_CONFIG", DEFAULT_CONFIG))
    parser.add_argument("--weights-dir",
                        default=os.environ.get("LAYA_WEIGHTS_DIR", DEFAULT_WEIGHTS))
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args(argv)

    if not os.path.exists(args.config):
        print("ERROR: config not found: %s" % args.config, file=sys.stderr)
        return 2
    config = load_config(args.config)

    if not (args.check or args.download or args.verify):
        parser.print_usage(sys.stderr)
        print("choose one of --check, --download, --verify", file=sys.stderr)
        return 2

    code = 0
    if args.check:
        code = cmd_check(config, args.weights_dir) or code
    if args.download:
        code = cmd_download(config, args.weights_dir) or code
    if args.verify:
        code = cmd_verify(config, args.weights_dir) or code
    return code


if __name__ == "__main__":
    sys.exit(main())
