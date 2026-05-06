#!/bin/bash
# =============================================================================
# run_enricher.sh — Production wrapper for csv_enricher
#
# Designed to be called by cron every minute.
# Picks up the latest CSV from WATCH_DIR, enriches it, saves to OUTPUT_DIR,
# and appends detailed logs to LOG_FILE on any error.
#
# Environment variables (all have defaults):
#   WATCH_DIR    — directory where new CSV files appear
#   OUTPUT_DIR   — directory to write enriched CSVs
#   CONFIG_FILE  — path to the rules config file
#   LOG_FILE     — path to the append-only error/event log
#   ENRICHER     — path to the csv_enricher binary
#   KEEP_DAYS    — how many days of output files to keep (default: 7)
# =============================================================================

set -uo pipefail

# ── Configuration (override via environment) ──────────────────────────────────
WATCH_DIR="${WATCH_DIR:-/var/data/csv_input}"
OUTPUT_DIR="${OUTPUT_DIR:-/var/data/csv_output}"
CONFIG_FILE="${CONFIG_FILE:-/etc/csv_enricher/rules.conf}"
LOG_FILE="${LOG_FILE:-/var/log/csv_enricher/enricher.log}"
ENRICHER="${ENRICHER:-/usr/local/bin/csv_enricher}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# ── Logging helpers ───────────────────────────────────────────────────────────
TIMESTAMP() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    local level="$1"; shift
    echo "[$(TIMESTAMP)] [$level] $*" >> "$LOG_FILE"
}

log_info()  { log "INFO " "$@"; }
log_warn()  { log "WARN " "$@"; }
log_error() { log "ERROR" "$@"; }

# Ensure the log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ── Startup checks ────────────────────────────────────────────────────────────
if [ ! -x "$ENRICHER" ]; then
    log_error "Binary not found or not executable: $ENRICHER"
    log_error "Run deploy.sh to install, or set ENRICHER=/path/to/csv_enricher"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"
    log_error "Create it with rules like: if price > 500 set tier p1"
    exit 1
fi

if [ ! -d "$WATCH_DIR" ]; then
    log_error "Watch directory not found: $WATCH_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── Find the latest CSV file in WATCH_DIR ─────────────────────────────────────
# Uses modification time — picks up files written/copied in the last 2 minutes
# (2 minutes window handles slight timing skew around cron's 1-minute boundary)
LATEST_CSV=$(find "$WATCH_DIR" -maxdepth 1 -name "*.csv" \
                 -newer "$WATCH_DIR" \
                 -type f 2>/dev/null | sort | tail -1)

# Fallback: if no file is newer than the dir, take the most recently modified
if [ -z "$LATEST_CSV" ]; then
    LATEST_CSV=$(find "$WATCH_DIR" -maxdepth 1 -name "*.csv" \
                     -type f 2>/dev/null \
                 | xargs ls -t 2>/dev/null | head -1)
fi

if [ -z "$LATEST_CSV" ]; then
    # No CSV found — not an error, just nothing to do this minute
    log_info "No CSV files in $WATCH_DIR — nothing to process."
    exit 0
fi

BASENAME=$(basename "$LATEST_CSV" .csv)

# ── Avoid reprocessing the same file twice ────────────────────────────────────
LOCK_FILE="/tmp/csv_enricher_last_processed"
if [ -f "$LOCK_FILE" ] && [ "$(cat "$LOCK_FILE")" = "$LATEST_CSV" ]; then
    log_info "Already processed $LATEST_CSV — skipping."
    exit 0
fi

# ── Run the enricher ──────────────────────────────────────────────────────────
TIMESTAMP_TAG=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="$OUTPUT_DIR/${BASENAME}_enriched_${TIMESTAMP_TAG}.csv"

log_info "Processing: $LATEST_CSV"
log_info "Output:     $OUTPUT_FILE"
log_info "Config:     $CONFIG_FILE"

# Capture stderr (progress + warnings) separately from stdout (CSV data)
STDERR_TMP=$(mktemp)

"$ENRICHER" "$CONFIG_FILE" "$LATEST_CSV" > "$OUTPUT_FILE" 2>"$STDERR_TMP"
EXIT_CODE=$?

# Always append enricher's stderr output to the log
while IFS= read -r line; do
    log_info "  [enricher] $line"
done < "$STDERR_TMP"

# ── Handle exit codes ─────────────────────────────────────────────────────────
case $EXIT_CODE in
    0)
        log_info "SUCCESS — output saved to $OUTPUT_FILE"
        echo "$LATEST_CSV" > "$LOCK_FILE"
        ;;
    2)
        # Partial success: some rows unclassified — log warning but keep output
        log_warn "PARTIAL — some rows were unclassified. Review rules in $CONFIG_FILE"
        log_warn "Output saved (may contain 'unclassified' values): $OUTPUT_FILE"
        echo "$LATEST_CSV" > "$LOCK_FILE"
        ;;
    *)
        # Hard failure — remove incomplete output file
        log_error "FAILED (exit code $EXIT_CODE) processing $LATEST_CSV"
        log_error "Incomplete output removed: $OUTPUT_FILE"
        rm -f "$OUTPUT_FILE"
        rm -f "$STDERR_TMP"
        exit "$EXIT_CODE"
        ;;
esac

rm -f "$STDERR_TMP"

# ── Clean up old output files ─────────────────────────────────────────────────
DELETED=$(find "$OUTPUT_DIR" -name "*_enriched_*.csv" \
               -mtime +"$KEEP_DAYS" -type f -print -delete 2>/dev/null | wc -l | tr -d ' ')
[ "$DELETED" -gt 0 ] && log_info "Cleaned up $DELETED output file(s) older than $KEEP_DAYS days"

exit 0
