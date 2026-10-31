@echo off
setlocal
chcp 65001 >nul
title Make Arabic Captions
rem  Portable: copy this one file to any Windows 10/11 PC. The first run installs
rem  everything it needs into %LOCALAPPDATA%\ArabicCaptions (no admin needed).
rem  To remove it later, delete that folder and
rem  %USERPROFILE%\.cache\huggingface\hub\models--Systran--faster-whisper-large-v3

set "APP=%LOCALAPPDATA%\ArabicCaptions"
set "UV=%APP%\uv\uv.exe"
set "PY=%APP%\venv\Scripts\python.exe"
set "STAMP=%APP%\installed-v1.txt"
set "SELF=%~f0"
set "UV_PYTHON_INSTALL_DIR=%APP%\python"
set "UV_PYTHON_PREFERENCE=only-managed"
set "UV_CACHE_DIR=%APP%\cache"
set "UV_NO_CONFIG=1"

if exist "%STAMP%" if exist "%PY%" goto run

echo ==============================================================
echo   First-time setup on this PC (only happens once).
echo   Downloads about 1-2 GB now, and the 3 GB speech model
echo   with the first video. Stay connected to the internet.
echo   If a firewall asks about curl, uv or python, allow it.
echo ==============================================================
echo.
if not exist "%APP%" mkdir "%APP%"
if exist "%UV%" goto have_uv
echo [1/3] Downloading the installer...
set "UVURL=https://github.com/astral-sh/uv/releases/download/0.12.2/uv-x86_64-pc-windows-msvc.zip"
curl.exe -L --fail --retry 3 -o "%APP%\uv.zip" "%UVURL%"
if not errorlevel 1 goto unzip_uv
echo       curl did not work, trying PowerShell...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -UseBasicParsing $env:UVURL -OutFile (Join-Path $env:APP 'uv.zip')"
if errorlevel 1 goto fail
:unzip_uv
if not exist "%APP%\uv" mkdir "%APP%\uv"
tar -xf "%APP%\uv.zip" -C "%APP%\uv"
if errorlevel 1 goto fail
del "%APP%\uv.zip"
:have_uv
echo [2/3] Installing Python and the speech libraries...
set "BASEPY=%APP%\python\cpython-3.13.14-windows-x86_64-none\python.exe"
if not exist "%BASEPY%" "%UV%" python install 3.13.14 --no-bin
if not exist "%BASEPY%" goto fail
"%UV%" venv --python "%BASEPY%" --allow-existing "%APP%\venv"
if errorlevel 1 goto fail
"%UV%" pip install --python "%PY%" faster-whisper==1.2.1 ctranslate2==4.8.4 av==19.0.2
if errorlevel 1 goto fail
where nvidia-smi >nul 2>nul
if errorlevel 1 goto no_gpu
echo [3/3] NVIDIA graphics card found, installing its speed-up libraries...
"%UV%" pip install --python "%PY%" nvidia-cublas-cu12==12.9.2.10 nvidia-cudnn-cu12==9.27.0.42
if errorlevel 1 echo       Could not install them. Captions will use the processor instead.
goto setup_done
:no_gpu
echo [3/3] No NVIDIA graphics card. Captions will use the processor (slower).
:setup_done
echo installed> "%STAMP%"
echo.
echo Setup finished.
echo.

:run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF); $m='#=='+'PYTHON==#'; $i=$t.LastIndexOf($m); [IO.File]::WriteAllText((Join-Path $env:APP 'make_captions.py'), $t.Substring($i+$m.Length).TrimStart(), (New-Object Text.UTF8Encoding $false))"
if errorlevel 1 goto fail
"%PY%" "%APP%\make_captions.py" %*
echo.
pause
exit /b

:fail
echo.
echo Setup did not finish. Check the internet connection (and allow any
echo firewall pop-up), then run this file again. It continues where it stopped.
echo.
pause
exit /b 1

#==PYTHON==#
"""Make Arabic captions (.srt) from any video or audio file with Whisper large-v3 (runs offline).

Run it by double-clicking "Make Arabic Captions.bat" on the Desktop (a file picker opens),
or drag a video onto that .bat file. The .srt is saved next to the video.

Settings you may want to change are just below.
"""
import os, sys, site, subprocess

for _s in (sys.stdout, sys.stderr):  # show Arabic text in the window
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

MAX_WORDS = 4      # words per caption
MAX_CHARS = 24     # characters per caption
PAUSE = 0.30       # a silence longer than this (seconds) starts a new caption
MIN_SHOW = 0.35    # shortest time a caption stays on screen (seconds)
LANGUAGE = "ar"    # Arabic
MODEL = os.environ.get("CAPTIONS_MODEL", "large-v3")  # Whisper model (about 3 GB)

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

# Let the GPU libraries installed with pip be found (faster on the NVIDIA card).
for sp in site.getsitepackages():
    for sub in ("nvidia/cublas/bin", "nvidia/cudnn/bin"):
        p = os.path.join(sp, *sub.split("/"))
        if os.path.isdir(p):
            os.add_dll_directory(p)
            os.environ["PATH"] = p + os.pathsep + os.environ["PATH"]


def pick_file():
    import tkinter as tk
    from tkinter import filedialog
    root = tk.Tk()
    root.withdraw()
    path = filedialog.askopenfilename(
        title="Choose a video or audio file to caption",
        filetypes=[("Video / audio", "*.mp4 *.mov *.mkv *.mpg *.mpeg *.avi *.webm *.wav *.mp3 *.m4a *.aac *.flac"),
                   ("All files", "*.*")])
    root.destroy()
    return path


def load_audio(path):
    """Decode any video or audio file to 16 kHz mono (PyAV, so no ffmpeg install is needed)."""
    import av
    import numpy as np
    parts = []
    try:
        with av.open(path) as box:
            stream = next((st for st in box.streams if st.type == "audio"), None)
            if stream is None:
                sys.exit("This file has no sound track.")
            rs = av.AudioResampler(format="s16", layout="mono", rate=16000)
            for frame in box.decode(stream):
                for f in rs.resample(frame):
                    parts.append(f.to_ndarray().reshape(-1))
            for f in rs.resample(None):
                parts.append(f.to_ndarray().reshape(-1))
    except av.FFmpegError as e:
        if not parts:
            sys.exit(f"Could not read this file: {e}")
        print("Warning: the end of the file is damaged; captioning what could be read.")
    if not parts:
        sys.exit("This file has no sound.")
    return np.concatenate(parts).astype(np.float32) / 32768


def model_path():
    """Use the model already on this PC; download it once if it is missing."""
    from faster_whisper.utils import download_model
    try:
        return download_model(MODEL, local_files_only=True)
    except Exception:
        pass
    print(f"Downloading the speech model '{MODEL}' (about 3 GB, only the first time)...")
    try:
        return download_model(MODEL)
    except Exception as e:
        sys.exit(f"Could not download the model. Check the internet connection and try again.\n({e})")


def run(model, audio):
    segments, info = model.transcribe(
        audio, language=LANGUAGE, word_timestamps=True, beam_size=5,
        vad_filter=True, condition_on_previous_text=False)
    phrases = []  # one list of (start, end, word) per spoken phrase
    total = len(audio) / 16000
    for s in segments:
        print(f"  {s.start:6.1f}s / {total:.0f}s  {s.text.strip()}")
        words = [(w.start, w.end, w.word.strip()) for w in (s.words or []) if w.word.strip()]
        if words:
            phrases.append(words)
    return phrases


def transcribe(audio):
    from faster_whisper import WhisperModel
    path = model_path()
    if os.environ.get("CAPTIONS_CPU") != "1":
        try:
            model = WhisperModel(path, device="cuda", compute_type="int8_float16")
            print("Using the graphics card (fast).")
            return run(model, audio)
        except Exception as e:
            print(f"Graphics card not usable ({str(e).splitlines()[0][:90]}).")
    print("Using the processor (slower: roughly 1-3x the video length).")
    return run(WhisperModel(path, device="cpu", compute_type="int8"), audio)


def split_even(run):
    """Split a run of words into the fewest captions that fit, with similar sizes."""
    k = -(-len(run) // MAX_WORDS)
    while True:
        size, extra = divmod(len(run), k)
        parts, i = [], 0
        for j in range(k):
            n = size + (1 if j < extra else 0)
            parts.append(run[i:i + n])
            i += n
        if k >= len(run) or all(len(" ".join(x[2] for x in p)) <= MAX_CHARS for p in parts):
            return parts
        k += 1


def chunk(phrases):
    chunks = []
    for words in phrases:
        run = []  # break a phrase at pauses and at ? ! . , first
        for w in words:
            if run and (w[0] - run[-1][1] > PAUSE or run[-1][2][-1:] in "\u061f?!.\u060c,"):
                chunks += split_even(run)
                run = []
            run.append(w)
        if run:
            chunks += split_even(run)
    out = []
    for i, ch in enumerate(chunks):
        s, e = ch[0][0], ch[-1][1]
        if i + 1 < len(chunks) and chunks[i + 1][0][0] - e < PAUSE:
            e = chunks[i + 1][0][0]  # no flicker between close captions
        e = max(e, s + MIN_SHOW)
        out.append((s, e, " ".join(x[2] for x in ch)))
    return out


def ts(t):
    ms = int(round(t * 1000))
    return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else pick_file()
    if not path:
        return
    print("File:", path)
    print("Reading audio...")
    audio = load_audio(path)
    print("Transcribing (the first run takes a moment to load the model)...")
    caps = chunk(transcribe(audio))
    out = os.path.splitext(path)[0] + "_ar.srt"
    with open(out, "w", encoding="utf-8-sig") as f:
        for i, (s, e, text) in enumerate(caps, 1):
            f.write(f"{i}\n{ts(s)} --> {ts(e)}\n{text}\n\n")
    print(f"\nDone: {len(caps)} captions saved to\n{out}")
    if os.name == "nt" and not os.environ.get("MAKE_CAPTIONS_NO_OPEN"):
        subprocess.run(["explorer", "/select,", out])


if __name__ == "__main__":
    main()
