
.PHONY: all deps prep ml psm ord bin clean

all: deps prep ml psm ord bin

deps:
	R -q -e "source('install.R')"

prep:
	R -q -e "source('R/01_data_prep.R')"

ml:
	R -q -e "source('R/02_modeling_ml.R')"

psm:
	R -q -e "source('R/03_psm_analysis.R')"

ord:
	R -q -e "source('R/04_ordinal_binary_models.R');"

bin:
	R -q -e "source('R/04_ordinal_binary_models.R');"

clean:
	rm -rf outputs/*
