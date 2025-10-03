#!/usr/bin/env bash
# mdai-usage-gen.sh — generate usage.md from mdai.sh (Bash 3.2+ / BSD awk compatible)
set -euo pipefail

IN=""
OUT="usage.md"
EXAMPLES=""
SECTION_ORDER=""   # e.g. "synopsis,globals,commands,defaults,examples"

usage() {
  cat <<'EOF'
mdai-usage-gen.sh

USAGE:
  ./mdai-usage-gen.sh --in ./mdai.sh [--out usage.md] [--examples ./cli-usage.md] [--section "synopsis,globals,commands,defaults,examples"]

FLAGS:
  --in FILE           Path to mdai.sh (required)
  --out FILE          Output markdown (default: usage.md)
  --examples FILE     Optional extra examples to append (e.g., cli-usage.md)
  --section ORDER     Comma-separated section list in desired order. Valid:
                      synopsis, globals, commands, defaults, examples
                      Omit sections by leaving them out. Unknown names ignored.
  -h, --help          Show this help

This script:
  • Runs `mdai.sh --help` to capture the official help block (falls back to parsing usage() if needed)
  • Extracts "GLOBAL FLAGS" and "COMMANDS" sections from that help
  • Parses top-level defaults from mdai.sh (VAR="${VAR:-...}" and VAR=true/false) using BSD-awk-safe logic
  • Optionally appends an Examples section from --examples
  • Lets you reorder/omit sections with --section
EOF
}

die() { echo "❌ $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in)       IN="${2:-}"; shift 2 ;;
    --out)      OUT="${2:-}"; shift 2 ;;
    --examples) EXAMPLES="${2:-}"; shift 2 ;;
    --section)  SECTION_ORDER="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) die "Unknown flag: $1";;
  esac
done

[[ -n "$IN" ]] || die "--in is required"
[[ -f "$IN" ]] || die "Input not found: $IN"
if [[ -n "$EXAMPLES" && ! -f "$EXAMPLES" ]]; then
  die "Examples file not found: $EXAMPLES"
fi

# ---- Helpers ---------------------------------------------------------------

# Capture the script's help text by invoking it, fallback to parsing usage() heredoc.
get_help_text() {
  local help=""
  if bash "$IN" --help >/tmp/_mdai_help.$$ 2>/dev/null; then
    help="$(cat /tmp/_mdai_help.$$)"
    rm -f /tmp/_mdai_help.$$
    printf "%s" "$help"
    return 0
  fi
  # Fallback: parse usage() heredoc
  awk '
    $0 ~ /^usage\(\)/ { infn=1; next }
    infn && $0 ~ /<<\047?EOF\047?/ { inhere=1; next }
    inhere && $0 ~ /^EOF$/ { inhere=0; infn=0 }
    inhere { print }
  ' "$IN"
}

# Extract a section by title (e.g., "GLOBAL FLAGS:" or "COMMANDS:")
extract_section() {
  local title="$1"
  awk -v t="$title" '
    BEGIN{insec=0}
    $0 ~ t {insec=1; next}
    insec {
      # Stop on next ALL-CAPS header line like "COMMANDS:" (allow leading spaces)
      if ($0 ~ /^[[:space:]]*[A-Z][A-Z _-]*:$/) { exit }
      print
    }
  '
}

# BSD-awk-safe defaults table:
#  - Detects lines like: VAR="${VAR:-default}"  (or "${VAR:default}")
#  - Detects booleans like: VAR=true / VAR=false
#  - Captures trailing comment after first # outside of double quotes as Note
extract_defaults_table() {
  awk '
    function ltrim(s){ sub(/^[ \t\r\n]+/,"",s); return s }
    function rtrim(s){ sub(/[ \t\r\n]+$/,"",s); return s }
    function trim(s){ return rtrim(ltrim(s)) }

    BEGIN{
      print "| Variable | Default | Note |"
      print "|---|---|---|"
    }

    /^[A-Z_][A-Z0-9_]*[ \t]*=/ {
      line=$0

      # Split off a trailing comment (first # outside quotes)
      inq=0; note=""; cutpos=0
      for (i=1; i<=length(line); i++) {
        c=substr(line,i,1)
        if (c=="\"" && substr(line,i-1,1)!="\\") { inq = !inq }
        if (!inq && c=="#") { cutpos=i; break }
      }
      if (cutpos>0) { note=substr(line,cutpos+1); line=substr(line,1,cutpos-1) }
      note=trim(note)

      # variable name (before first =)
      var=line; sub(/[ \t]*=.*/, "", var)

      # rhs after =
      rhs=line; sub(/^[^=]*=/,"",rhs)
      rhs=trim(rhs)

      # Case 1: boolean true/false
      if (rhs ~ /^(true|false|True|False)$/) {
        print "| " var " | " rhs " | " note " |"
        next
      }

      # Case 2: pattern containing ${...} default
      pos=index(rhs, "${")
      if (pos==0) next

      inner=substr(rhs, pos+2)   # after ${
      rbpos=index(inner, "}")    # <-- avoid clash with awk builtin close()
      if (rbpos==0) next
      inner=substr(inner, 1, rbpos-1)

      # inner like: VAR:-default  OR  VAR:default
      colon=index(inner, ":")
      if (colon==0) next

      defpart=substr(inner, colon+1)
      if (substr(defpart,1,1)=="-") {
        defpart=substr(defpart,2)
      }

      defval=trim(defpart)
      # strip surrounding double quotes if present
      if (substr(defval,1,1)=="\"" && substr(defval,length(defval),1)=="\"") {
        defval=substr(defval,2,length(defval)-2)
      }

      print "| " var " | " defval " | " note " |"
    }
  ' "$IN"
}

# Trim leading/trailing blank lines of a block
trim_block() {
  awk '
    { lines[NR]=$0 }
    END{
      s=1; while (s<=NR && lines[s] ~ /^[[:space:]]*$/) s++
      e=NR; while (e>=s && lines[e] ~ /^[[:space:]]*$/) e--
      for(i=s;i<=e;i++) print lines[i]
    }
  '
}

lower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

# Normalize a requested section token
normalize_section() {
  case "$(lower "$1")" in
    synopsis|help)                        echo "synopsis" ;;
    globals|global|global-flags|flags)    echo "globals" ;;
    commands|cmds|cmd)                    echo "commands" ;;
    defaults|vars|variables)              echo "defaults" ;;
    examples|example|ex)                  echo "examples" ;;
    *)                                    echo "" ;;
  esac
}

# Compute effective section order
compute_order() {
  local order_csv="$1"
  local -a ORDER=()
  if [[ -n "$order_csv" ]]; then
    IFS=',' read -r s1 s2 s3 s4 s5 s6 <<<"$order_csv"
    for tok in "$s1" "$s2" "$s3" "$s4" "$s5" "$s6"; do
      [[ -n "${tok:-}" ]] || continue
      local norm
      norm="$(normalize_section "$(echo "$tok" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")"
      [[ -n "$norm" ]] && ORDER+=("$norm")
    done
  fi
  if [ ${#ORDER[@]} -eq 0 ]; then
    ORDER=(synopsis globals commands defaults examples)
  fi
  # Dedup
  local -a DEDUP=()
  for s in "${ORDER[@]}"; do
    local seen=0
    for t in "${DEDUP[@]:-}"; do [[ "$s" == "$t" ]] && { seen=1; break; }; done
    (( seen == 0 )) && DEDUP+=("$s")
  done
  printf "%s\n" "${DEDUP[@]}"
}

# ---- Gather content --------------------------------------------------------

HELP_TEXT="$(get_help_text | sed -e "s/\r$//")"
[[ -n "$HELP_TEXT" ]] || die "Could not capture help from $IN"

GLOBAL_FLAGS="$(printf "%s\n" "$HELP_TEXT" | extract_section '^GLOBAL FLAGS:')"
COMMANDS_TXT="$(printf "%s\n" "$HELP_TEXT" | extract_section '^COMMANDS:')"

GLOBAL_FLAGS="$(printf "%s\n" "$GLOBAL_FLAGS" | trim_block)"
COMMANDS_TXT="$(printf "%s\n" "$COMMANDS_TXT" | trim_block)"

DEFAULTS_TABLE="$(extract_defaults_table)"
EXAMPLES_TXT=""
if [[ -n "$EXAMPLES" ]]; then
  EXAMPLES_TXT="$(cat "$EXAMPLES")"

  # If the examples file starts with a triple-backtick fence (e.g., ``` or ```markdown),
  # remove the FIRST line; if the LAST line is exactly ``` remove it too.
  # This unwraps a top-level fence while preserving any inner code blocks.
  if printf "%s\n" "$EXAMPLES_TXT" | head -n1 | grep -qE '^[`]{3}'; then
    EXAMPLES_TXT="$(printf "%s\n" "$EXAMPLES_TXT" | sed '1{/^```/d;}' | sed '$ { /^```$/d; }')"
  fi
fi

ORDERED_SECTIONS="$(compute_order "${SECTION_ORDER:-}")"

# ---- Write file ------------------------------------------------------------

SCRIPT_NAME="$(basename "$IN")"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

{
  echo "# ${SCRIPT_NAME} — Usage"
  echo
  echo "_Generated on ${NOW}_"
  echo

  while IFS= read -r SECTION; do
    case "$SECTION" in
      synopsis)
        echo "## Synopsis (from \`--help\`)"
        echo
        echo '```text'
        echo "$HELP_TEXT"
        echo '```'
        echo
        ;;
      globals)
        echo "## Global Flags"
        echo
        if [[ -n "$GLOBAL_FLAGS" ]]; then
          echo '```text'
          echo "$GLOBAL_FLAGS"
          echo '```'
        else
          echo "_No global flags section detected in the help text._"
        fi
        echo
        ;;
      commands)
        echo "## Commands"
        echo
        if [[ -n "$COMMANDS_TXT" ]]; then
          echo '```text'
          echo "$COMMANDS_TXT"
          echo '```'
        else
          echo "_No commands section detected in the help text._"
        fi
        echo
        ;;
      defaults)
        echo "## Defaults (auto-detected)"
        echo
        echo "$DEFAULTS_TABLE"
        echo
        ;;
      examples)
        if [[ -n "$EXAMPLES_TXT" ]]; then
          echo "## Examples"
          echo
          echo "$EXAMPLES_TXT"
          echo
        fi
        ;;
    esac
  done <<< "$ORDERED_SECTIONS"
} >"$OUT"

echo "✅ Wrote ${OUT}"
