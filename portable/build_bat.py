"""Build the portable "Make Arabic Captions.bat": header.bat + make_captions.py in one file.

Run:  py portable\\build_bat.py            (writes "Make Arabic Captions.bat" in the repo root)
      py portable\\build_bat.py --desktop  (also copies it to your Desktop)
"""
import os, shutil, sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
header = open(os.path.join(here, "header.bat"), encoding="ascii").read()
script = open(os.path.join(root, "make_captions.py"), encoding="ascii").read()

text = header.rstrip() + "\n\n#==PYTHON==#\n" + script
out = os.path.join(root, "Make Arabic Captions.bat")
with open(out, "w", encoding="ascii", newline="\r\n") as f:
    f.write(text)
print("Built", out)

if "--desktop" in sys.argv:
    desk = os.path.join(os.path.expanduser("~"), "Desktop", "Make Arabic Captions.bat")
    shutil.copyfile(out, desk)
    print("Copied to", desk)
