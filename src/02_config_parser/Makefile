CC     = gcc
FLEX   = flex
BISON  = bison
TARGET = config_parser

all: $(TARGET)

config.tab.c config.tab.h: config.y
	$(BISON) -d config.y

lex.yy.c: config.l config.tab.h
	$(FLEX) config.l

$(TARGET): lex.yy.c config.tab.c
	$(CC) -o $@ $^ -I.

clean:
	rm -f $(TARGET) config.tab.c config.tab.h lex.yy.c

.PHONY: all clean
