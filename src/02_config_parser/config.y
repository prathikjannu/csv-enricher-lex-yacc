%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int  yylex(void);
%}

%union {
    char   *str;
    double  num;
}

%token <str> IDENTIFIER
%token <num> NUMBER
%token IF SET GT LT GTE LTE EQ NEQ NEWLINE

%%

config:
    rules
;

rules:
    rules rule
  | rule
;

/*
 * Each rule has the form:
 *   if <field> <op> <threshold> set <column> <label>
 * e.g.: if price > 500 set tier p1
 */
rule:
    IF IDENTIFIER GT  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s > %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | IF IDENTIFIER LT  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s < %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | IF IDENTIFIER GTE NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s >= %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | IF IDENTIFIER LTE NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s <= %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | IF IDENTIFIER EQ  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s == %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | IF IDENTIFIER NEQ NUMBER SET IDENTIFIER IDENTIFIER NEWLINE {
        printf("Rule: if %-8s != %7.2f  =>  set %-8s = %s\n", $2, $4, $6, $7);
        free($2); free($6); free($7);
    }
  | NEWLINE           { /* skip blank/comment lines */ }
;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Config parse error: %s\n", s);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <config.conf>\n", argv[0]);
        return 1;
    }
    extern FILE *yyin;
    yyin = fopen(argv[1], "r");
    if (!yyin) { perror(argv[1]); return 1; }

    printf("=== Parsed Config Rules ===\n");
    yyparse();
    fclose(yyin);
    return 0;
}
