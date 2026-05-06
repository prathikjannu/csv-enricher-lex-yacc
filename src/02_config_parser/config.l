%option noyywrap

%{
#include "config.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%%

"if"                        { return IF; }
"set"                       { return SET; }
">="                        { return GTE; }
"<="                        { return LTE; }
"=="                        { return EQ; }
"!="                        { return NEQ; }
">"                         { return GT; }
"<"                         { return LT; }

[0-9]+(\.[0-9]+)?           { yylval.num = atof(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]*     { yylval.str = strdup(yytext); return IDENTIFIER; }

\r?\n                       { return NEWLINE; }
[ \t]+                      { /* skip whitespace */ }
#[^\n]*                     { /* skip comment lines */ }

%%
