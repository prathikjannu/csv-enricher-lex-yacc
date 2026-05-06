%option noyywrap

%{
#include "csv.tab.h"
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
