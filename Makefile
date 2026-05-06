# Top-level Makefile — delegates to each phase's sub-Makefile
.PHONY: all csv config enricher clean

all: csv config enricher

csv:
	$(MAKE) -C src/01_csv_parser

config:
	$(MAKE) -C src/02_config_parser

enricher:
	$(MAKE) -C src/03_csv_enricher

clean:
	$(MAKE) -C src/01_csv_parser  clean
	$(MAKE) -C src/02_config_parser clean
	$(MAKE) -C src/03_csv_enricher  clean
