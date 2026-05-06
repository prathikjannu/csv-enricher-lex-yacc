/*
 * shared.h — types and extern declarations shared between parsers and main.c
 *
 * Phase 3 uses a STREAMING design: only one CSV row is held in memory at a
 * time, so memory use is O(1) regardless of how large the CSV file is.
 */
#ifndef SHARED_H
#define SHARED_H

#define MAX_RULES  100
#define MAX_COLS   50
#define MAX_LEN    256

/* Comparison operators supported in config rules */
typedef enum {
    OP_GT  = 0,   /* >  */
    OP_LT  = 1,   /* <  */
    OP_GTE = 2,   /* >= */
    OP_LTE = 3,   /* <= */
    OP_EQ  = 4,   /* == */
    OP_NEQ = 5    /* != */
} OpType;

/* A single parsed config rule: "if <field> <op> <threshold> set <column> <label>" */
typedef struct {
    char   field[MAX_LEN];     /* CSV column to test, e.g. "price" */
    OpType op;                 /* comparison operator               */
    double threshold;          /* numeric threshold                  */
    char   column[MAX_LEN];    /* new column name, e.g. "tier"      */
    char   label[MAX_LEN];     /* value to assign, e.g. "p1"        */
} Rule;

/* Populated by the config parser (small — at most MAX_RULES entries) */
extern Rule rules[MAX_RULES];
extern int  rule_count;

/*
 * Streaming CSV state — only ONE row is live in memory at a time.
 *   header[]   : column names from row 0
 *   cur_row[]  : fields of the row currently being parsed
 *   col_count  : number of columns (set after header row)
 *   is_header  : 1 while parsing row 0, 0 afterwards
 */
extern char csv_header[MAX_COLS][MAX_LEN];
extern char csv_cur_row[MAX_COLS][MAX_LEN];
extern int  csv_col_count;
extern int  csv_is_header;      /* 1 = parsing header row */

/* Called by the CSV parser after each complete row is accumulated.
 * is_header=1 means this is the header row, 0 means a data row. */
extern void csv_flush_row(int is_header);

#endif /* SHARED_H */
