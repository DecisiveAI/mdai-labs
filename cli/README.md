## Using `./cli/mdai-usage-gen.sh`

This is a step-by-step guide for using **`mdai-usage-gen.sh`** to produce a nice `usage.md` from  `./cli/mdai.sh`.

### What the script does

* Runs `mdai.sh --help` (or falls back to parsing the `usage()` heredoc) to grab the official help text.

* Extracts the **GLOBAL FLAGS** and **COMMANDS** sections.

* Scans `mdai.sh` for top-level defaults like `VAR="${VAR:-default}"` and `VAR=true/false` and renders a **Defaults (auto-detected)** table.

* Optionally appends your own **Examples** section from a file you provide.

* Lets you control which sections appear and in what order via `--section`.

### Prerequisites

* MacOS or Linux shell with: `bash`, `awk`, `sed`, `date`.

* The `mdai.sh` file should either:

  * Print usage with `--help` **without failing**, or

  * Contain a `usage()` function with an `EOF` heredoc (the script can parse that).

* (Optional) An examples file (markdown or plain text) if you want a custom **Examples** section.

### Install

```bash
chmod +x mdai-usage-gen.sh
```

### Basic usage

Generate `usage.md` from `mdai.sh`:

```bash
# make sure to run commands from the cli/ directory
cd cli

./mdai-usage-gen.sh --in ./mdai.sh --out ./usage.md
```

### Add examples

Append any examples kept in a separate file (e.g., `cli-usage.md`) to the end of the doc:

```bash
# make sure to run commands from the cli/ directory
cd cli

./mdai-usage-gen.sh --in ./mdai.sh --out ./usage.md --examples ./cli-usage.md
```

* The file is included **verbatim** inside an “## Examples” section.

* The section appears only if `--examples` points to an existing file **and** the section is included in the order (see below).

### Choose section order (and omit sections)

use `--section` with a comma-separated list (case-insensitive). valid tokens:
`synopsis, globals, commands, defaults, examples`

```bash
# make sure to run commands from the cli/ directory
cd cli

# Default order (if you omit --section)
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md
# => synopsis, globals, commands, defaults, examples

# Put Examples after Commands and omit Defaults
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md \
  --examples ./cli-usage.md \
  --section "synopsis,globals,commands,examples"

# Only Commands (no Synopsis/Globals/Defaults/Examples)
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md \
  --section "commands"
```

Notes:

* Unknown tokens are ignored.

* Duplicates are de-duplicated, first occurrence wins.


### Directory layout tips

Common layouts that work well:

```
repo/
├─ mdai.sh
├─ mdai-usage-gen.sh
├─ cli-usage.md           # optional: your curated examples
└─ docs/
   └─ usage.md            # output destination
```

Generate straight into `docs/usage.md`:

```bash
# make sure to run commands from the cli/ directory
cd cli

./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md --examples ./cli-usage.md
```

### Makefile / npm / CI integration

**Makefile**

```make
.PHONY: usage
usage:
	./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md --examples ./cli-usage.md --section "synopsis,globals,commands,defaults,examples"
```

**GitHub Actions (snippet)**

```yaml
- name: Generate usage.md
  run: |
    chmod +x mdai-usage-gen.sh
    ./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md --examples ./cli-usage.md
- name: Commit docs
  run: |
    git add docs/usage.md
    git diff --quiet && echo "No changes" || git commit -m "docs: update usage.md"
```

### Output format

* **Synopsis**: the entire `--help` text wrapped in a code fence./

* **Global Flags**/**Commands**: extracted subsections from the help.

* **Defaults**: markdown table with `Variable | Default | Note`.

* **Examples**: whatever you put in the examples file, verbatim.

----

### Troubleshooting

**“Examples file not found”**

* Your `--examples` path must exist. Fix the path or omit the flag.


**“Could not capture help from mdai.sh”**

* Ensure `bash ./mdai.sh --help` exits 0 and prints usage.
  if your script exits non-zero on `--help`, adjust it to `exit 0`.

* If you rely on the fallback, ensure your `usage()` function uses a clean `<<EOF … EOF` heredoc.


**awk syntax errors (macOS)**

* This generator is written for **BSD awk** (macOS) compatibility. if you still see awk errors, check for unusual default lines in `mdai.sh` (non-standard patterns).

**Defaults missing/incorrect**

* The parser recognizes:

  * `VAR="${VAR:-default}"` (also `VAR="${VAR:default}"`)

  * `VAR=true` / `VAR=false`

  * Optional trailing comments (`# note here`) are captured as the “Note”.

* If you keep defaults in other forms (e.g., computed in functions), they won’t be auto-detected—add a note manually in your examples file or we can extend the parser.

----

### Best practices

* Ensure `mdai.sh --help` prints everything users need (synopsis, global flags, commands).

* Keep `cli-usage.md` focused: real copy-paste recipes and common flows.

* Run the generator in CI so `usage.md` never drifts from the script.

* When you add new globals or commands, update the help text in `mdai.sh`; the generator will pick them up automatically.


### Quick commands you’ll actually run

```bash
# make sure to run commands from the cli/ directory
cd cli

# 1) Most common: generate docs
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md

# 2) Generate docs with examples
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md --examples ./cli-usage.md

# 2) Generate only synopsis + commands
./mdai-usage-gen.sh --in ./mdai.sh --out ./docs/usage.md --section "synopsis,commands"
```
