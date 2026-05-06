/*
 * main.c — CSV Enricher (Phase 3) — STREAMING edition
 *
 * Memory usage is O(1) with respect to CSV size:
 *   - Config rules are loaded fully (small: at most MAX_RULES entries).
 *   - Only ONE CSV row is in memory at any time; each row is evaluated
 *     and written to stdout immediately by csv_flush_row(), then discarded.
 *
 * This handles CSV files of any size (100k, 1M+ rows) without issue.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "shared.h"

/* ── Global data definitions (extern'd in shared.h) ── */
Rule rules[MAX_RULES];
int  rule_count    = 0;

char csv_header[MAX_COLS][MAX_LEN];
char csv_cur_row[MAX_COLS][MAX_LEN];
int  csv_col_count = 0;
int  csv_is_header = 1;   /* starts as 1; csv.y clears it after row 0 */

/* ── Parser entry points ── */
extern int conf_parse(void);
extern int csv_parse(void);

/* ── Input file pointers (flex-generated, renamed by %option prefix) ── */
extern FILE *conf_in;
extern FILE *csv_in;

/* ── Counters for progress reporting ── */
static long data_rows_written  = 0;
static long unclassified_count = 0;

/* ── Evaluate a single rule against csv_cur_row[] ── */
static int evaluate_rule(const Rule *r) {
    int col_idx = -1;
    for (int c = 0; c < csv_col_count; c++) {
        if (strcmp(csv_header[c], r->field) == 0) {
            col_idx = c;
            break;
        }
    }
    if (col_idx < 0) return 0;

    double val = atof(csv_cur_row[col_idx]);
    switch (r->op) {
        case OP_GT:  return val >  r->threshold;
        case OP_LT:  return val <  r->threshold;
        case OP_GTE: return val >= r->threshold;
        case OP_LTE: return val <= r->threshold;
        case OP_EQ:  return val == r->threshold;
        case OP_NEQ: return val != r->threshold;
    }
    return 0;
}

/*
 * csv_flush_row — called by the CSV parser after every complete row.
 * is_header=1 → print header line + new column name.
 * is_header=0 → evaluate rules, append label, print data row.
 * The current-row buffer is always cleared so the next row starts fresh.
 */
void csv_flush_row(int is_header) {
    if (is_header) {
        /* Validate that every rule references a real column */
        for (int i = 0; i < rule_count; i++) {
            int found = 0;
            for (int c = 0; c < csv_col_count; c++) {
                if (strcmp(csv_header[c], rules[i].field) == 0) { found = 1; break; }
            }
            if (!found) {
                fprintf(stderr,
                    "WARNING: rule %d references field '%s' which is not in the CSV header.\n",
                    i + 1, rules[i].field);
            }
        }

        for (int c = 0; c < csv_col_count; c++) {
            if (c > 0) putchar(',');
            fputs(csv_header[c], stdout);
        }
        printf(",%s\n", rules[0].column);
        return;
    }

    /* Data row: evaluate rules, first match wins */
    const char *label = NULL;
    for (int i = 0; i < rule_count; i++) {
        if (evaluate_rule(&rules[i])) {
            label = rules[i].label;
            break;
        }
    }

    if (!label) {
        label = "unclassified";
        unclassified_count++;
    }

    for (int c = 0; c < csv_col_count; c++) {
        if (c > 0) putchar(',');
        fputs(csv_cur_row[c], stdout);
    }
    printf(",%s\n", label);

    data_rows_written++;

    /* Progress report to stderr every 10,000 rows */
    if (data_rows_written % 10000 == 0) {
        fprintf(stderr, "  ... %ld rows processed\n", data_rows_written);
    }

    /* Clear row buffer for next row */
    memset(csv_cur_row, 0, sizeof(csv_cur_row));
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <config.conf> <input.csv>\n", argv[0]);
        fprintf(stderr, "  config.conf  rules like: if price > 500 set tier p1\n");
        fprintf(stderr, "  input.csv    CSV file (any size — streamed row by row)\n");
        return 1;
    }

    /* Step 1: Parse config → load rules[] (fully in memory — small) */
    conf_in = fopen(argv[1], "r");
    if (!conf_in) { perror(argv[1]); return 1; }
    conf_parse();
    fclose(conf_in);

    if (rule_count == 0) {
        fprintf(stderr, "Error: no rules found in '%s'.\n", argv[1]);
        return 1;
    }
    fprintf(stderr, "Loaded %d rule(s) from config.\n", rule_count);

    /* Step 2: Stream CSV — each row is flushed immediately by csv_flush_row() */
    csv_in = fopen(argv[2], "r");
    if (!csv_in) { perror(argv[2]); return 1; }

    fprintf(stderr, "Streaming CSV (row-by-row, constant memory)...\n");
    csv_parse();
    fclose(csv_in);

    fprintf(stderr, "Done. %ld data row(s) written.\n", data_rows_written);
    if (unclassified_count > 0) {
        fprintf(stderr,
            "WARNING: %ld row(s) matched no rule and were labelled 'unclassified'.\n"
            "         Check that your config field names match the CSV header.\n",
            unclassified_count);
        return 2;   /* non-zero exit so scripts can detect partial failures */
    }
    return 0;
}
