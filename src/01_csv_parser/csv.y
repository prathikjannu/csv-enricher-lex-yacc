%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int  yylex(void);

static int col_count = 0;
static int row_num   = 0;
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
                        printf("\n");
                        row_num++;
                        col_count = 0;
                    }
  | NEWLINE         { /* skip blank lines */ }
;

fields:
    fields COMMA field
  | field
;

field:
    STRING  {
                if (col_count > 0) printf(",");
                printf("%s", $1);
                free($1);
                col_count++;
            }
;

%%

void yyerror(const char *s) {
    fprintf(stderr, "CSV parse error: %s\n", s);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <file.csv>\n", argv[0]);
        return 1;
    }
    extern FILE *yyin;
    yyin = fopen(argv[1], "r");
    if (!yyin) { perror(argv[1]); return 1; }

    printf("=== Parsed CSV ===\n");
    yyparse();
    fclose(yyin);
    printf("=== Total rows parsed: %d (including header) ===\n", row_num);
    return 0;
}
