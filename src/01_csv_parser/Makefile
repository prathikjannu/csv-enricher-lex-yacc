CC     = gcc
FLEX   = flex
BISON  = bison
TARGET = csv_parser

all: $(TARGET)

csv.tab.c csv.tab.h: csv.y
	$(BISON) -d csv.y

lex.yy.c: csv.l csv.tab.h
	$(FLEX) csv.l

$(TARGET): lex.yy.c csv.tab.c
	$(CC) -o $@ $^ -I.

clean:
	rm -f $(TARGET) csv.tab.c csv.tab.h lex.yy.c

.PHONY: all clean
