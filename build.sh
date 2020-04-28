#!/bin/bash

INPUT_FILES=$(cat main.md)
TEX_FILE="report.tex"

pandoc --standalone --from markdown \
       -F pandoc-tablenos -F pandoc-crossref -F pandoc-citeproc --bibliography=bibliography.bib \
       --template templates/eisvogel.latex --listings --toc -V toc-title='Table of contents' \
       -V linkcolor:blue -V mainfont="Times New Roman" -V monofont="DejaVu Sans Mono" -V sansfont="Arial" \
       -V 'sansfontoptions:LetterSpace=4.0' --number-sections --pdf-engine=xelatex -V titlepage \
       -V titlepage-color=C6E4F5 -V titlepage-text-color=393939 -V toc-own-page \
       -V logo="ITU_logo_UK.jpg" -V logo-width=250 \
       $INPUT_FILES -o "$TEX_FILE"

# TODO: "-V listings-no-page-break" causes empty TOC
# --syntax-definition /Users/runesvendsen/Documents/ITU/06BSc/code/RuleLangHs/data/rulelang.xml \

FONTS_DIR="/Library/Fonts/"
docker run -v "$(pwd)/:/doc/" -v "$FONTS_DIR:/usr/share/fonts/external/" -i thomasweise/texlive xelatex "$TEX_FILE"
