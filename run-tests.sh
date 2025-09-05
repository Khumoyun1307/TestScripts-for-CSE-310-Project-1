#!/usr/bin/env bash
# Dynamic test runner for PJ1 posted cases
# Usage: bash run-tests.sh PJ1-Posted-Test-Cases
# Optional: EXE=./PJ1.exe bash run-tests.sh PJ1-Posted-Test-Cases

ROOT="${1:-PJ1-Posted-Test-Cases}"
EXE="${EXE:-./PJ1}"    # set EXE env var if you built PJ1.exe

normalize() {          # normalize CRLF->LF
  sed 's/\r$//' "$1"
}

find_case_file() {     # find file (case variants)
  local d="$1"; shift
  for n in "$@"; do
    [ -f "$d/$n" ] && { printf '%s' "$d/$n"; return 0; }
  done
  return 1
}

parse_flag() {         # last token must be integer
  awk '{for(i=1;i<=NF;i++) last=$i} END{ if(last~/^-?[0-9]+$/){print last; exit 0}else exit 1 }' "$1"
}

[ -x "$EXE" ] || { echo "ERROR: cannot find executable: $EXE"; exit 1; }
[ -d "$ROOT" ] || { echo "ERROR: cannot find cases dir: $ROOT"; exit 1; }

tests=( $(find "$ROOT" -maxdepth 1 -type d -regex ".*/test[0-9][0-9]" | sort) )

pass=0; fail=0; total=0

for td in "${tests[@]}"; do
  [ -d "$td" ] || continue
  name=$(basename "$td")
  total=$((total+1))

  # locate files
  execf=$(find_case_file "$td" Execution execution) || { echo "[$name] ERROR: no Execution"; fail=$((fail+1)); continue; }
  ifile=$(find_case_file "$td" I-File I-file I_file Ifile) || { echo "[$name] ERROR: no I-File"; fail=$((fail+1)); continue; }
  instr=$(find_case_file "$td" Instructions instructions) || { echo "[$name] ERROR: no Instructions"; fail=$((fail+1)); continue; }
  expout=$(find_case_file "$td" Output output) || { echo "[$name] ERROR: no Output"; fail=$((fail+1)); continue; }
  expof=$(find_case_file "$td" O-File O-file O_file Ofile) || { echo "[$name] ERROR: no O-File"; fail=$((fail+1)); continue; }

  # parse flag
  if ! flag=$(parse_flag "$execf"); then
    echo "[$name] ERROR: cannot parse flag"; fail=$((fail+1)); continue
  fi

  mystd="$td/student.Output"
  myof="$td/student.O-File"
  rm -f "$mystd" "$myof" "$td/student.stderr"

  echo "[$name] Running... flag=$flag"
  "$EXE" "$ifile" "$myof" "$flag" < "$instr" > "$mystd" 2> "$td/student.stderr"

  if diff -u <(normalize "$mystd") <(normalize "$expout") >/dev/null 2>&1 \
     && diff -u <(normalize "$myof")  <(normalize "$expof")  >/dev/null 2>&1
  then
    echo "[$name] PASS"
    pass=$((pass+1))
  else
    echo "[$name] FAIL"
    echo "  stdout diff:"
    diff -u <(normalize "$mystd") <(normalize "$expout") || true
    echo "  ofile diff:"
    diff -u <(normalize "$myof")  <(normalize "$expof") || true
    echo "  stderr (if any):"
    [ -s "$td/student.stderr" ] && sed 's/\r$//' "$td/student.stderr" | sed -n '1,10p' || echo "  (empty)"
    fail=$((fail+1))
  fi
done

echo
echo "Summary: $pass passed, $fail failed (of $total)"
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
