# Make Arabic Captions

One double-click turns a video into an Arabic subtitle file (`.srt`) with short captions of 2–4 words, ready for Premiere Pro, CapCut, DaVinci Resolve or YouTube.

It runs **offline on your own PC** with OpenAI's Whisper `large-v3` model (through [faster-whisper](https://github.com/SYSTRAN/faster-whisper)), and it handles spoken dialect well.

## Use it

1. Download **[Make Arabic Captions.bat](https://github.com/nagasab221/Arabic-Captions/releases/latest/download/Make.Arabic.Captions.bat)**. That one file is the whole program.
2. Double-click it, or drag a video onto it, and pick your video.
3. `<your video>_ar.srt` appears next to the video.

### First run on a PC

The first run sets itself up: no admin rights, nothing to install by hand. It needs internet:

| What | Size |
|---|---|
| A private copy of Python plus the speech libraries | about 1 GB (about 2.4 GB with an NVIDIA GPU) |
| The Whisper `large-v3` speech model, fetched with the first video | about 3 GB |

After that it works offline. If setup is interrupted, run the file again and it carries on.

- **With an NVIDIA graphics card:** a 35-second clip takes about 20 seconds.
- **Without one:** it uses the processor, at roughly 2–3× the video's length.

Requirements: Windows 10 or 11 on 64-bit Intel/AMD. ARM laptops are not supported.

Files go to:
- `%LOCALAPPDATA%\ArabicCaptions`: Python and the libraries.
- `%USERPROFILE%\.cache\huggingface`: the model.

To uninstall, delete both folders.

## Always proofread

Whisper is very good but not perfect. It can mishear dialect words and sometimes invents a word over laughter or noise.

## Settings

Open the `.bat` in Notepad and find the `#==PYTHON==#` line. The settings are just below it:

```python
MAX_WORDS = 4      # words per caption
MAX_CHARS = 24     # characters per caption
LANGUAGE = "ar"    # "en" for English, etc.
```

## How it's built

- `make_captions.py`: the caption script. It reads audio with PyAV and transcribes with Whisper using word timestamps and VAD. It then splits each spoken phrase at pauses and punctuation into even captions of 2–4 words.
- `portable/header.bat`: the self-installer. It downloads [uv](https://github.com/astral-sh/uv), installs Python 3.13.14, and installs pinned versions of faster-whisper, CTranslate2 and PyAV. It adds the CUDA libraries only when `nvidia-smi` is present.
- `portable/build_bat.py`: joins the two into `Make Arabic Captions.bat`. After editing the script, run:

```bash
py portable/build_bat.py
```
