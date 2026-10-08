#!/usr/bin/env bash
# Compile the LaTeX CV and place the PDF at the project root as cv.pdf, where the
# CV page's "Download PDF" button links to it.
#
# Run from anywhere:  ./cv_source/build-pdf.sh
set -euo pipefail

export PATH="/Library/TeX/texbin:$PATH"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
TEX="CV_Andrea_Vaiano_no_dati"

# TeX Live ships biber as a universal binary that self-extracts on first run. On some
# Apple Silicon setups that extraction fails ("extracting arm64 binary with lipo
# failed"). If plain biber can't even report its version, thin out the native slice
# ourselves and use that instead.
resolve_biber() {
  if biber --version >/dev/null 2>&1; then
    echo "biber"
    return
  fi
  local arch cache
  arch="$(uname -m)"
  cache="${TMPDIR:-/tmp}/biber-$arch"
  if [ ! -x "$cache" ]; then
    echo "biber is broken on this machine; extracting the $arch slice..." >&2
    lipo "$(command -v biber)" -thin "$arch" -output "$cache" >&2
    chmod +x "$cache"
  fi
  if ! "$cache" --version >/dev/null 2>&1; then
    echo "ERROR: could not get a working biber. The bibliography would be missing." >&2
    exit 1
  fi
  echo "$cache"
}

BIBER="$(resolve_biber)"

cd "$HERE"
pdflatex -interaction=nonstopmode -halt-on-error "$TEX.tex" > /dev/null
"$BIBER" "$TEX" > /dev/null          # resolves the bibliography from bibliocv.bib
pdflatex -interaction=nonstopmode "$TEX.tex" > /dev/null
pdflatex -interaction=nonstopmode "$TEX.tex" > /dev/null

# Fail loudly rather than silently shipping a CV with no publications.
if ! grep -q '\\field{title}' "$TEX.bbl" 2>/dev/null; then
  echo "ERROR: $TEX.bbl has no entries — the bibliography did not resolve." >&2
  exit 1
fi

cp "$TEX.pdf" "$ROOT/cv.pdf"
echo "Built $ROOT/cv.pdf ($(grep -o 'Output written.*' "$TEX.log" | tail -1))"
