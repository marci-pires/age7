.PHONY: help vars parse extract full-extract ingest data validate notify load all clean

include config.mk

help: 
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

datapackage.json: datapackage.yaml schemas/* data/* logs/validate/* schemas/dialect.json README.md CHANGELOG.md CONTRIBUTING.md
	dtamg-py etl-make build-datapackage

init: ## Create boilerplate files for the derivated datapackages
	dtamg-py etl-make build-documentation-folder

parse: $(SQL_FILES)

$(SQL_FILES): scripts/sql/%.sql: scripts/r/parse-sql.R schemas/%.yaml renv.lock
	Rscript --verbose $< $* 2> logs/parse/$*.Rout

full-extract:
	# python scripts/python/full-extract.py
	dtamg-py etl-make full-extract 2>> logs/full_extract.txt

extract: $(DATA_RAW_FILES) ## Extract raw files from external source into data/raw/

$(DATA_RAW_FILES): data/raw/%.csv: scripts/python/extract-resource.py scripts/sql/%.sql
	python $< $* 2> logs/extract/$*.txt

ingest: $(DATA_INGEST_FILES) ## Ingest raw files (data/raw/) into staging area (data/staging/)

$(DATA_INGEST_FILES): data/staging/%.csv: data/raw/%.csv
	rsync --checksum data/raw/* data/staging/

data: $(DATA_FILES) ## Compress staged files (data/staging/) to data/

$(DATA_FILES): data/%.csv.gz : data/staging/%.csv 
	gzip -n < data/staging/$*.csv > data/$*.csv.gz

validate: $(VALIDATION_FILES)

test: $(TEST_FILES)

$(TEST_FILES): logs/tests/test_%.Rout: tests/testthat/test_%.R data/%.csv.gz tests/testthat.R tests/testthat/setup.R renv.lock
	Rscript --verbose -e "testthat::test_file('$<', stop_on_failure=TRUE)" 2> $@

notify:
	Rscript --verbose scripts/r/notify.R 2> logs/notify.Rout

build:
	dtamg-py etl-make build-datapackages 2> logs/build.txt

create:
	dtamg-py etl-make dpckan-create 2> logs/create.txt

update:
	dtamg-py etl-make dpckan-update 2> logs/update.txt

$(VALIDATION_FILES): logs/validate/%.json: data/%.csv.gz
	dtamg-py etl-make validate -r $* >$@

validate-metadata: ## Valida arquivo yaml com tableschema
	@echo "Validando tableschemas"
	@dtamg-py etl-make validate-tableschemas

vars: 
	@echo 'DATA_FILES:' $(DATA_FILES)

clean:
	rm -rf logs/parse/*
	rm -rf scripts/sql/*
	rm -rf logs/extract/*
	rm -rf data/raw/*
	rm -rf data/staging/*
	rm -f data/*.csv.gz
	rm -rf logs/validate/*
	rm -f logs/*.txt
	rm -rf logs/tests/*
	rm -f datapackage.json
	rm -rf build_datasets
