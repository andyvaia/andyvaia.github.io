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

cd "$HERE"
pdflatex -interaction=nonstopmode -halt-on-error "$TEX.tex" > /dev/null
biber "$TEX" > /dev/null          # resolves the bibliography from bibliocv.bib
pdflatex -interaction=nonstopmode "$TEX.tex" > /dev/null
pdflatex -interaction=nonstopmode "$TEX.tex" > /dev/null

cp "$TEX.pdf" "$ROOT/cv.pdf"
echo "Built $ROOT/cv.pdf"
