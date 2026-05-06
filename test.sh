#!/bin/bash
# test.sh — automated test suite for the Lex & Yacc CSV Enricher project
# Run from the project root:  bash test.sh

ROOT="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓ PASS${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}  $1"; ((FAIL++)); }
section() { echo -e "\n${YELLOW}── $1 ──${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
section "Build"
# ─────────────────────────────────────────────────────────────────────────────
make -C "$ROOT" --quiet 2>&1
if [ $? -eq 0 ]; then
  pass "make builds all three phases without errors"
else
  fail "make failed — fix build errors before running tests"
  exit 1
fi

CSV_P="$ROOT/src/01_csv_parser/csv_parser"
CFG_P="$ROOT/src/02_config_parser/config_parser"
ENR_P="$ROOT/src/03_csv_enricher/csv_enricher"

# ─────────────────────────────────────────────────────────────────────────────
section "Phase 1 — CSV Parser"
# ─────────────────────────────────────────────────────────────────────────────

# T1: parses the sample file and produces the correct number of output lines
OUT=$("$CSV_P" "$ROOT/data/input.csv" 2>/dev/null)
LINES=$(echo "$OUT" | grep -c '^[0-9]')
[ "$LINES" -eq 4 ] && pass "parses 4 data rows from input.csv" \
                    || fail "expected 4 data rows, got $LINES"

# T2: header row is present
echo "$OUT" | grep -q "^id,name,price" \
  && pass "header row printed correctly" \
  || fail "header row not found in output"

# T3: exit code 1 when no file is provided
"$CSV_P" 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 when no argument given" \
  || fail "expected exit code 1 for missing argument"

# T4: exit code 1 for non-existent file
"$CSV_P" /tmp/does_not_exist.csv 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 for non-existent file" \
  || fail "expected exit code 1 for missing file"

# ─────────────────────────────────────────────────────────────────────────────
section "Phase 2 — Config Rule Parser"
# ─────────────────────────────────────────────────────────────────────────────

# T5: parses two rules
OUT=$("$CFG_P" "$ROOT/data/sample.conf" 2>/dev/null)
RULES=$(echo "$OUT" | grep -c "^Rule:")
[ "$RULES" -eq 2 ] && pass "parses 2 rules from sample.conf" \
                    || fail "expected 2 rules, got $RULES"

# T6: rule content is correct
echo "$OUT" | grep -q "price" && echo "$OUT" | grep -q "p1" \
  && pass "rule references correct field and label" \
  || fail "rule content incorrect"

# T7: exit code 1 when no file is provided
"$CFG_P" 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 when no argument given" \
  || fail "expected exit code 1 for missing argument"

# ─────────────────────────────────────────────────────────────────────────────
section "Phase 3 — CSV Enricher (correctness)"
# ─────────────────────────────────────────────────────────────────────────────

OUT=$("$ENR_P" "$ROOT/data/sample.conf" "$ROOT/data/input.csv" 2>/dev/null)

# T8: header has new column
echo "$OUT" | head -1 | grep -q "tier" \
  && pass "output header contains new column 'tier'" \
  || fail "output header missing 'tier' column"

# T9: high-price row gets p1
echo "$OUT" | grep "MacBook" | grep -q "p1" \
  && pass "MacBook (price=999) correctly labelled p1" \
  || fail "MacBook should be p1"

# T10: high-price row gets p1
echo "$OUT" | grep "iPhone" | grep -q "p1" \
  && pass "iPhone (price=699) correctly labelled p1" \
  || fail "iPhone should be p1"

# T11: low-price row gets p2
echo "$OUT" | grep "iPad" | grep -q "p2" \
  && pass "iPad (price=299) correctly labelled p2" \
  || fail "iPad should be p2"

# T12: low-price row gets p2
echo "$OUT" | grep "AirPods" | grep -q "p2" \
  && pass "AirPods (price=149) correctly labelled p2" \
  || fail "AirPods should be p2"

# T13: output row count = input rows + header (4 data + 1 header = 5)
TOTAL=$(echo "$OUT" | wc -l | tr -d ' ')
[ "$TOTAL" -eq 5 ] && pass "output has correct row count (4 data + 1 header)" \
                    || fail "expected 5 output lines, got $TOTAL"

# T14: output is valid CSV (same number of commas per row)
COMMA_COUNTS=$(echo "$OUT" | awk -F',' '{print NF}' | sort -u)
[ "$(echo "$COMMA_COUNTS" | wc -l | tr -d ' ')" -eq 1 ] \
  && pass "all output rows have the same number of fields" \
  || fail "inconsistent number of fields across rows"

# ─────────────────────────────────────────────────────────────────────────────
section "Phase 3 — CSV Enricher (error handling)"
# ─────────────────────────────────────────────────────────────────────────────

# T15: exit code 1 for missing args
"$ENR_P" 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 when no arguments given" \
  || fail "expected exit code 1 for missing arguments"

# T16: exit code 1 for non-existent config
"$ENR_P" /tmp/nope.conf "$ROOT/data/input.csv" 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 for non-existent config file" \
  || fail "expected exit code 1 for missing config"

# T17: exit code 1 for non-existent CSV
"$ENR_P" "$ROOT/data/sample.conf" /tmp/nope.csv 2>/dev/null; [ $? -eq 1 ] \
  && pass "exits with code 1 for non-existent CSV file" \
  || fail "expected exit code 1 for missing CSV"

# T18: bad field name → exit code 2 (partial failure) + warning on stderr
STDERR=$("$ENR_P" "$ROOT/data/bad_field.conf" "$ROOT/data/input.csv" 2>&1 >/dev/null)
EXIT=$?
[ $EXIT -eq 2 ] && pass "exits with code 2 when no rules match (wrong field)" \
                || fail "expected exit code 2 for unmatched rules, got $EXIT"

# T19: warning message mentions the bad field
echo "$STDERR" | grep -qi "WARNING" \
  && pass "prints WARNING when field not found in CSV header" \
  || fail "expected WARNING message for unknown field"

# T20: output still written (not silently dropped)
ROWS=$("$ENR_P" "$ROOT/data/bad_field.conf" "$ROOT/data/input.csv" 2>/dev/null | grep -c "unclassified")
[ "$ROWS" -eq 4 ] && pass "all rows still output as 'unclassified' (not silently dropped)" \
                  || fail "expected 4 unclassified rows, got $ROWS"

# ─────────────────────────────────────────────────────────────────────────────
section "Phase 3 — Large file (performance)"
# ─────────────────────────────────────────────────────────────────────────────

# Generate a 10k row file for the CI-friendly performance check
python3 -c "
import random, csv, sys
w = csv.writer(sys.stdout)
w.writerow(['id','name','price'])
for i in range(1, 10001):
    w.writerow([i, 'item', random.randint(50, 1500)])
" > /tmp/perf_test.csv 2>/dev/null

START=$(date +%s%N)
"$ENR_P" "$ROOT/data/sample.conf" /tmp/perf_test.csv > /tmp/perf_out.csv 2>/dev/null
END=$(date +%s%N)
MS=$(( (END - START) / 1000000 ))
ROWS=$(wc -l < /tmp/perf_out.csv | tr -d ' ')

[ "$ROWS" -eq 10001 ] \
  && pass "10k rows → correct output count ($ROWS lines including header)" \
  || fail "expected 10001 output lines, got $ROWS"

[ "$MS" -lt 5000 ] \
  && pass "10k rows processed in ${MS}ms (< 5s threshold)" \
  || fail "10k rows took ${MS}ms — too slow"

rm -f /tmp/perf_test.csv /tmp/perf_out.csv

# ─────────────────────────────────────────────────────────────────────────────
section "Results"
# ─────────────────────────────────────────────────────────────────────────────
TOTAL_TESTS=$((PASS + FAIL))
echo ""
echo -e "  ${GREEN}Passed: $PASS${NC} / $TOTAL_TESTS"
[ $FAIL -gt 0 ] && echo -e "  ${RED}Failed: $FAIL${NC} / $TOTAL_TESTS"
echo ""
[ $FAIL -eq 0 ] && echo -e "${GREEN}All tests passed ✓${NC}" \
               || echo -e "${RED}$FAIL test(s) failed ✗${NC}"
[ $FAIL -eq 0 ] && exit 0 || exit 1
