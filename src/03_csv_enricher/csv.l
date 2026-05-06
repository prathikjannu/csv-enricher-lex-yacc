/* CSV lexer for Phase 3 — uses prefix "csv_" to avoid symbol conflicts */
%option noyywrap prefix="csv_"

%{
#include "csv.tab.h"
/* Map yylval → csv_lval (bison 2.3 does not auto-alias it in the header) */
#define yylval csv_lval
#include <stdlib.h>
#include <string.h>
%}

%%

\"[^\"]*\"          {
                        /* Quoted field: strip surrounding double quotes */
                        yytext[yyleng - 1] = '\0';
                        yylval.str = strdup(yytext + 1);
                        return STRING;
                    }

[^,\n\r\"]+         { yylval.str = strdup(yytext); return STRING; }

","                 { return COMMA; }

\r?\n               { return NEWLINE; }

%%
