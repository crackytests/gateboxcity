"""Extract all text from Interface Zero 2.0 PDF using pypdf."""
from pypdf import PdfReader
import sys

PDF_PATH = r"F:\downloads\Interface Zero 2.0 - Core Rulebook.pdf"
OUT_PATH = r"C:\Users\jeremy\Documents\New project\tools\iz2_raw.txt"

reader = PdfReader(PDF_PATH)
total = len(reader.pages)
print(f"Total pages: {total}", flush=True)

with open(OUT_PATH, "w", encoding="utf-8") as f:
    for i, page in enumerate(reader.pages):
        if i % 20 == 0:
            print(f"  page {i}/{total}...", flush=True)
        text = page.extract_text() or ""
        f.write(f"\n\n===PAGE {i+1}===\n{text}")

print(f"Done. Written to {OUT_PATH}")
