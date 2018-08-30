
all:
	./download-rkernels-from-dataset.sh
	Rscript ./format_script.R

clean:
	rm -R ./Data/*
