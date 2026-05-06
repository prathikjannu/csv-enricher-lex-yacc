/* CSV grammar for Phase 3 — STREAMING: flushes each row immediately */
%name-prefix="csv_"

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "shared.h"

int  csv_lex(void);
void csv_error(const char *s);

static int cur_col = 0;   /* column index within the current row */
%}

%union {
    char *str;
}

%token <str> STRING
%token COMMA NEWLINE

%%

file:
    rows
;

rows:
    rows row
  | row
;

row:
    fields NEWLINE  {
                        int was_header = csv_is_header;
                        if (csv_is_header) {
                            csv_col_count = cur_col;
                            csv_is_header = 0;
                        }
                        csv_flush_row(was_header);
                        cur_col = 0;
                    }
  | NEWLINE         { /* skip blank lines */ }
;

fields:
    fields COMMA field
  | field
;

field:
    STRING  {
                if (cur_col < MAX_COLS) {
                    strncpy(csv_cur_row[cur_col], $1, MAX_LEN - 1);
                    csv_cur_row[cur_col][MAX_LEN - 1] = '\0';
                    /* Also copy to header array on the first row */
                    if (csv_is_header) {
                        strncpy(csv_header[cur_col], $1, MAX_LEN - 1);
                        csv_header[cur_col][MAX_LEN - 1] = '\0';
                    }
                }
                free($1);
                cur_col++;
            }
;

%%

void csv_error(const char *s) {
    fprintf(stderr, "CSV parse error: %s\n", s);
}
