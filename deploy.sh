#!/bin/bash
# =============================================================================
# deploy.sh — Build and install csv_enricher to a production server
#
# Usage:
#   bash deploy.sh                         # install to /usr/local/bin
#   INSTALL_DIR=/opt/csv_enricher bash deploy.sh  # custom install path
#
# What it does:
#   1. Builds the binary from source (requires flex, bison, gcc)
#   2. Copies the binary to INSTALL_DIR
#   3. Copies the config and scripts to INSTALL_DIR
#   4. Creates log directory
#   5. Prints cron setup instructions
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/csv_enricher}"
LOG_DIR="${LOG_DIR:-/var/log/csv_enricher}"
WATCH_DIR="${WATCH_DIR:-/var/data/csv_input}"
OUTPUT_DIR="${OUTPUT_DIR:-/var/data/csv_output}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ── 1. Check dependencies ─────────────────────────────────────────────────────
info "Checking build dependencies..."
for cmd in flex bison gcc; do
  command -v "$cmd" >/dev/null 2>&1 || error "$cmd not found. Install it first:
    Ubuntu/Debian: sudo apt-get install flex bison gcc
    RHEL/CentOS:   sudo yum install flex bison gcc
    macOS:         xcode-select --install"
done
info "  flex: $(flex --version | head -1)"
info "  bison: $(bison --version | head -1)"
info "  gcc: $(gcc --version | head -1)"

# ── 2. Build ──────────────────────────────────────────────────────────────────
info "Building csv_enricher..."
make -C "$SCRIPT_DIR" enricher --quiet || error "Build failed. Run 'make enricher' for details."
BINARY="$SCRIPT_DIR/src/03_csv_enricher/csv_enricher"
[ -x "$BINARY" ] || error "Binary not found after build: $BINARY"
info "  Build OK → $BINARY"

# ── 3. Install binary ─────────────────────────────────────────────────────────
info "Installing binary to $INSTALL_DIR/csv_enricher ..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp "$BINARY" "$INSTALL_DIR/csv_enricher"
sudo chmod 755 "$INSTALL_DIR/csv_enricher"
info "  Installed ✓"

# ── 4. Install config directory ───────────────────────────────────────────────
info "Installing config to $CONFIG_DIR ..."
sudo mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/rules.conf" ]; then
  sudo cp "$SCRIPT_DIR/data/sample.conf" "$CONFIG_DIR/rules.conf"
  info "  Copied default rules.conf (edit to customise)"
else
  warn "  $CONFIG_DIR/rules.conf already exists — not overwritten"
fi

# ── 5. Create runtime directories ─────────────────────────────────────────────
info "Creating runtime directories..."
sudo mkdir -p "$LOG_DIR" "$WATCH_DIR" "$OUTPUT_DIR"
# Allow the current user (or the cron user) to write to these dirs
sudo chmod 1777 "$WATCH_DIR" "$OUTPUT_DIR"
sudo chmod 755  "$LOG_DIR"
info "  Watch dir:  $WATCH_DIR"
info "  Output dir: $OUTPUT_DIR"
info "  Log dir:    $LOG_DIR"

# ── 6. Install the run script ─────────────────────────────────────────────────
info "Installing run script to $INSTALL_DIR/csv_enricher_run.sh ..."
sudo cp "$SCRIPT_DIR/scripts/run_enricher.sh" "$INSTALL_DIR/csv_enricher_run.sh"
sudo chmod 755 "$INSTALL_DIR/csv_enricher_run.sh"

# ── 7. Install logrotate config (Linux only) ──────────────────────────────────
if [ -d /etc/logrotate.d ]; then
  info "Installing logrotate config..."
  sudo tee /etc/logrotate.d/csv_enricher > /dev/null << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    copytruncate
}
EOF
  info "  Logrotate configured (daily, 30-day retention)"
fi

# ── 8. Verify installation ────────────────────────────────────────────────────
info "Verifying installation..."
"$INSTALL_DIR/csv_enricher" 2>&1 | grep -q "Usage" \
  && info "  Binary runs OK ✓" \
  || error "  Binary failed to run"

# ── 9. Print cron setup ───────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW} CRON SETUP — run this to add the every-minute job:${NC}"
echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
echo ""
echo "  crontab -e"
echo ""
echo "  Add this line:"
echo ""
echo -e "  ${GREEN}* * * * * $INSTALL_DIR/csv_enricher_run.sh >> $LOG_DIR/cron.log 2>&1${NC}"
echo ""
echo "  Environment variables you can customise in the cron line:"
echo "    WATCH_DIR   — where your CSV files appear  (default: $WATCH_DIR)"
echo "    OUTPUT_DIR  — where enriched CSVs are saved (default: $OUTPUT_DIR)"
echo "    CONFIG_FILE — path to rules.conf            (default: $CONFIG_DIR/rules.conf)"
echo "    LOG_FILE    — path to error log             (default: $LOG_DIR/enricher.log)"
echo ""
echo -e "  Example with custom dirs:"
echo -e "  ${GREEN}* * * * * WATCH_DIR=/home/user/data OUTPUT_DIR=/home/user/out $INSTALL_DIR/csv_enricher_run.sh${NC}"
echo ""
echo -e "${GREEN}Deployment complete ✓${NC}"
