# Lex & Yacc: CSV Enricher

A hands-on project showing how **Lex** and **Yacc** work together to parse text files, built in three progressive phases.

---

## What is Lex & Yacc?

### Lex (Flex)
A **lexical analyser generator**. You write regular expressions in a `.l` file describing what each token looks like, and Lex generates C code that breaks raw text into a stream of tokens.

```
Input text  →  Lex (.l file)  →  Token stream
"price,499"     regex rules       STRING COMMA STRING
```

Key concepts:
- `yytext` — the matched text
- `yyleng` — its length
- `yylval` — the semantic value passed to the parser
- `yylex()` — the function the parser calls to get the next token

### Yacc (Bison)
A **parser generator** (Yet Another Compiler-Compiler). You write a BNF-style grammar in a `.y` file describing the structure of your language, and Yacc generates C code that consumes the token stream and executes actions.

```
Token stream  →  Yacc (.y file)  →  Structured output / actions
STRING COMMA    grammar rules       build parse tree, store data
```

Key concepts:
- `$$` — the value of the left-hand side of a rule
- `$1`, `$2`, ... — values of each component in a rule
- `yyparse()` — the generated function that drives parsing

### Data Flow

```
┌──────────────┐   raw text    ┌─────────────────────────┐
│  Input File  │ ───────────▶  │   LEX  (csv.l / conf.l) │
└──────────────┘               │   - regex rules          │
                               │   - returns tokens       │
                               └────────────┬────────────┘
                                            │  token stream
                                            │  (yylex calls)
                                            ▼
                               ┌─────────────────────────┐
                               │  YACC  (csv.y / conf.y) │
                               │  - grammar rules        │
                               │  - semantic actions {}  │
                               └────────────┬────────────┘
                                            │  result
                                            ▼
                               Parsed data structure / output
```

---

## Project Structure

```
laxyacc/
├── Makefile                    # build all phases
├── README.md
├── data/
│   ├── input.csv               # sample CSV to enrich
│   └── sample.conf             # conditional rules
└── src/
    ├── 01_csv_parser/          # Phase 1: standalone CSV parser
    │   ├── csv.l               # Lex: tokenise CSV fields
    │   ├── csv.y               # Yacc: parse CSV grammar, print rows
    │   └── Makefile
    ├── 02_config_parser/       # Phase 2: standalone config rule parser
    │   ├── config.l            # Lex: tokenise rule keywords & values
    │   ├── config.y            # Yacc: parse rule grammar, print rules
    │   └── Makefile
    └── 03_csv_enricher/        # Phase 3: combined enricher
        ├── shared.h            # shared types & extern declarations
        ├── csv.l               # CSV lexer  (prefix: csv_)
        ├── csv.y               # CSV parser (prefix: csv_) → fills csv_rows[][]
        ├── conf.l              # Config lexer  (prefix: conf_)
        ├── conf.y              # Config parser (prefix: conf_) → fills rules[]
        ├── main.c              # orchestrates both parsers; outputs enriched CSV
        └── Makefile
```

---

## Build

```bash
# Build all phases
make

# Build a single phase
make csv        # Phase 1
make config     # Phase 2
make enricher   # Phase 3

# Clean generated files
make clean
```

Requirements: `flex`, `bison`, `gcc` (all standard on macOS/Linux).

---

## Platform Support

### macOS / Linux
Works out of the box. Install tools if missing:
```bash
# macOS
xcode-select --install          # installs flex, bison, gcc

# Ubuntu / Debian / WSL
sudo apt install flex bison gcc make -y

# CentOS / RHEL
sudo yum install flex bison gcc make -y
```

---

### Windows

The tool runs on **WSL2** (recommended) or **MSYS2** — both free and take about 5 minutes to set up.

#### Option A — WSL2 (Recommended for Windows 10/11)

WSL2 gives you a full Linux environment inside Windows. Your Windows folders (including where the CSV is generated) are automatically accessible at `/mnt/c/`, `/mnt/d/`, etc.

**Step 1 — Install WSL2** (one time, in PowerShell as Administrator):
```powershell
wsl --install
# Restart your PC when prompted
```

**Step 2 — Install build tools** (in the WSL/Ubuntu terminal):
```bash
sudo apt update && sudo apt install flex bison gcc make git -y
```

**Step 3 — Clone and build**:
```bash
git clone https://github.com/prathikjannu/csv-enricher-lex-yacc.git
cd csv-enricher-lex-yacc
make
```

**Step 4 — Point to your Windows CSV folder**:

Your Windows drives are mounted automatically. For example, if your CSV lands in `C:\Data\exports\`:
```bash
# Run enricher directly on the Windows folder
./src/03_csv_enricher/csv_enricher data/sample.conf \
    /mnt/c/Data/exports/sales.csv > /mnt/c/Data/exports/sales_enriched.csv
```

**Step 5 — Schedule with Windows Task Scheduler** (instead of cron):

Create a file `run_enricher.bat` on Windows:
```bat
@echo off
wsl bash /home/<your-user>/csv-enricher-lex-yacc/scripts/run_enricher.sh
```

Then in **Task Scheduler**:
- Action → New → Program: `C:\path\to\run_enricher.bat`
- Trigger → New → Daily, repeat every **1 minute**

Or use the cron inside WSL (runs whenever WSL is active):
```bash
crontab -e
# Add:
* * * * * WATCH_DIR=/mnt/c/Data/exports OUTPUT_DIR=/mnt/c/Data/enriched bash ~/csv-enricher-lex-yacc/scripts/run_enricher.sh
```

---

#### Option B — MSYS2 (native Windows, no WSL)

**Step 1 — Install MSYS2** from https://www.msys2.org (free download)

**Step 2 — Install tools** (in the MSYS2 UCRT64 terminal):
```bash
pacman -S --noconfirm mingw-w64-ucrt-x86_64-gcc flex bison make git
```

**Step 3 — Clone and build**:
```bash
git clone https://github.com/prathikjannu/csv-enricher-lex-yacc.git
cd csv-enricher-lex-yacc
make
```

**Step 4 — Run on Windows paths** (use forward slashes in MSYS2):
```bash
./src/03_csv_enricher/csv_enricher data/sample.conf \
    "C:/Data/exports/sales.csv" > "C:/Data/exports/sales_enriched.csv"
```

---

#### Windows — CSV folder watch summary

| Your setup | Recommended approach |
|---|---|
| CSV generated on Windows, process on same machine | WSL2 + `/mnt/c/` path |
| CSV generated on Windows, process on Linux server | Share folder via network mount or SFTP |
| Fully Windows, no WSL | MSYS2 Option B above |

---

## Usage

### Phase 1 — CSV Parser
Parses any CSV file and echoes the fields.
```bash
./src/01_csv_parser/csv_parser data/input.csv
```
```
=== Parsed CSV ===
id,name,price
1,MacBook,999
...
=== Total rows parsed: 5 (including header) ===
```

### Phase 2 — Config Rule Parser
Parses a file of conditional rules.
```bash
./src/02_config_parser/config_parser data/sample.conf
```
Config file format:
```
# comment lines are ignored
if price > 500 set tier p1
if price < 500 set tier p2
```
Supported operators: `>`, `<`, `>=`, `<=`, `==`, `!=`

Output:
```
=== Parsed Config Rules ===
Rule: if price    >  500.00  =>  set tier     = p1
Rule: if price    <  500.00  =>  set tier     = p2
```

### Phase 3 — CSV Enricher
Combines both parsers: applies config rules to every CSV row and appends a new column.
```bash
./src/03_csv_enricher/csv_enricher data/sample.conf data/input.csv
```
```
Loaded 2 rule(s) from config.
Parsed 4 row(s) + 1 header from CSV.
id,name,price,tier
1,MacBook,999,p1
2,iPhone,699,p1
3,iPad,299,p2
4,AirPods,149,p2
```

Save the enriched CSV:
```bash
./src/03_csv_enricher/csv_enricher data/sample.conf data/input.csv > output.csv
```

---

## How Two Parsers Coexist in One Program

Normally Lex and Yacc generate functions named `yylex()`, `yyparse()`, `yyin`, etc. Linking two parsers together would cause symbol conflicts. Phase 3 solves this with **prefix renaming**:

| Phase 3 symbol    | Generated from         | Description                  |
|-------------------|------------------------|------------------------------|
| `csv_lex()`       | `flex %option prefix="csv_"` | CSV tokeniser              |
| `csv_parse()`     | `bison %name-prefix="csv_"` | CSV parser                  |
| `csv_in`          | flex (renamed `yyin`)  | CSV file input pointer       |
| `conf_lex()`      | `flex %option prefix="conf_"` | Config tokeniser          |
| `conf_parse()`    | `bison %name-prefix="conf_"` | Config parser              |
| `conf_in`         | flex (renamed `yyin`)  | Config file input pointer    |

`main.c` sets `conf_in` and calls `conf_parse()` first, then sets `csv_in` and calls `csv_parse()`.

---

## Extending the Config Rules

You can reference any column in the CSV:
```
if price   > 1000 set segment premium
if price   < 1000 set segment standard
if price  == 699  set segment flagship
```

Rules are evaluated top-to-bottom; the first matching rule wins. Rows that match no rule get `unclassified`.
