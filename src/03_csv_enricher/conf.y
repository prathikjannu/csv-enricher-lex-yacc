/* Config grammar for Phase 3 — stores rules in the shared global array */
%name-prefix="conf_"

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "shared.h"

int  conf_lex(void);
void conf_error(const char *s);

/* Helper: add a parsed rule to the global rules array */
static void add_rule(const char *field, OpType op, double threshold,
                     const char *column, const char *label) {
    if (rule_count >= MAX_RULES) return;
    strncpy(rules[rule_count].field,     field,     MAX_LEN - 1);
    rules[rule_count].op        = op;
    rules[rule_count].threshold = threshold;
    strncpy(rules[rule_count].column,    column,    MAX_LEN - 1);
    strncpy(rules[rule_count].label,     label,     MAX_LEN - 1);
    rule_count++;
}
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
 * Grammar: if <field> <op> <threshold> set <column> <label>
 * Example: if price > 500 set tier p1
 */
rule:
    IF IDENTIFIER GT  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_GT,  $4, $6, $7); free($2); free($6); free($7); }
  | IF IDENTIFIER LT  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_LT,  $4, $6, $7); free($2); free($6); free($7); }
  | IF IDENTIFIER GTE NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_GTE, $4, $6, $7); free($2); free($6); free($7); }
  | IF IDENTIFIER LTE NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_LTE, $4, $6, $7); free($2); free($6); free($7); }
  | IF IDENTIFIER EQ  NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_EQ,  $4, $6, $7); free($2); free($6); free($7); }
  | IF IDENTIFIER NEQ NUMBER SET IDENTIFIER IDENTIFIER NEWLINE
        { add_rule($2, OP_NEQ, $4, $6, $7); free($2); free($6); free($7); }
  | NEWLINE { /* skip blank/comment lines */ }
;

%%

void conf_error(const char *s) {
    fprintf(stderr, "Config parse error: %s\n", s);
}
