# Build individual subfile TeX documents.
#
# subfiles uses \documentclass[../preamble]{subfiles}, so pdflatex must be
# invoked from the *same directory as the .tex file* — not from src/spec/.
# This Makefile enforces that by cd-ing into the file's own directory first.
#
# Usage:
#   make                          # build all .tex subfiles
#   make foundations/category     # build one file (no .tex extension)
#   make clean                    # remove build artefacts
#
# The pandoc/docs pipeline (docs/build.sh) is the primary build path.
# Use this Makefile for direct PDF output during spec authoring.

SHELL := /bin/bash

# Collect all subfiles (exclude preamble.tex, which is the root document)
SUBFILES := $(shell find . -name '*.tex' ! -name 'preamble.tex' | sort)
PDFS     := $(patsubst %.tex,%.pdf,$(SUBFILES))

.PHONY: all clean

all: $(PDFS)

# Pattern rule: cd into the file's own directory, then run pdflatex there.
# This ensures ../preamble resolves correctly.
%.pdf: %.tex
	@dir=$$(dirname $<); base=$$(basename $< .tex); \
	echo "  pdflatex $$dir/$$base.tex"; \
	cd "$$dir" && pdflatex -interaction=nonstopmode "$$base.tex" > /dev/null

clean:
	find . -name '*.pdf' -o -name '*.aux' -o -name '*.log' \
	       -o -name '*.toc' -o -name '*.out' | xargs -r rm -f
