MAIN=pattern-paper
PROG=InconsistentConstraints

all:
	pdflatex $(MAIN)

bib:
	pdflatex $(MAIN)
	bibtex $(MAIN)
	pdflatex $(MAIN)
	bibtex $(MAIN)
	pdflatex $(MAIN)

prog:
	ocamlopt -g -o $(PROG) $(PROG).ml

clean: 
	rm -f *.aux *.log *.out $(MAIN).bbl main.blg main.pdf

