CC      = gcc
FLEX    = flex
BISON   = bison
TARGET  = csv_enricher
VERSION = $(shell cat ../../VERSION)
CFLAGS  = -DVERSION=\"$(VERSION)\"

all: $(TARGET)

# ── CSV parser (all symbols prefixed with csv_) ──────────────────────────────
csv.tab.c csv.tab.h: csv.y
	$(BISON) -d csv.y

csv_lex.c: csv.l csv.tab.h
	$(FLEX) -o csv_lex.c csv.l

# ── Config parser (all symbols prefixed with conf_) ──────────────────────────
conf.tab.c conf.tab.h: conf.y
	$(BISON) -d conf.y

conf_lex.c: conf.l conf.tab.h
	$(FLEX) -o conf_lex.c conf.l

# ── Link everything together ──────────────────────────────────────────────────
$(TARGET): csv_lex.c csv.tab.c conf_lex.c conf.tab.c main.c
	$(CC) $(CFLAGS) -o $@ $^ -I.

clean:
	rm -f $(TARGET) \
	      csv.tab.c csv.tab.h csv_lex.c \
	      conf.tab.c conf.tab.h conf_lex.c

.PHONY: all clean
