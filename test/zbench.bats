###################################################-*- mode: shell-script -*-###

set -eu

################################################################################
# Test setup

function setup_file() {
  bats_require_minimum_version 1.5.0;

  TEST_DIRNAME=${BATS_TEST_DIRNAME/#$PWD\//.\/};
  case $TEST_DIRNAME in
    */test ) export ROOT=${TEST_DIRNAME%/test};;
    test   ) export ROOT=.;;
    .      ) export ROOT=..;;
    *      ) export ROOT=$TEST_DIRNAME/..;;
  esac;
  export ZBENCH=$ROOT/src/functions/zbench;

  export FG_RED=$'\E[31m'; # Foreground color: Red
  export FG_GRN=$'\E[32m'; # Foreground color: Green
  export FG_YLW=$'\E[33m'; # Foreground color: Yellow
  export FG_DEF=$'\E[39m'; # Foreground color: Default
  export NL=$'\n';
}

function setup() {
  BREW_PREFIX="$(brew --prefix)";
  load "$BREW_PREFIX/lib/bats-support/load.bash";
  load "$BREW_PREFIX/lib/bats-assert/load.bash";
}

################################################################################
# Helper functions

function join() {
  local delimiter=${1:-};
  local first=${2:-};
  if shift 2; then
    printf %s "$first" "${@/#/$delimiter}";
  fi;
}

# fail+ <header> <info-line>...
function fail+() {
  local header="$1"; shift 1;
  fail "$(join "$NL" "" "-- $header --" "$@" "--")";
}

# array_show <array-name> header
function array_show() {
  local array=$1; header=$2;
  eval "local size=\${#$array[@]}";
  eval "local elements=(\"\${$array[@]}\")";
  local s="s"; ((size!=1)) || s="";
  echo "$header ($size element$s):";
  local element; for element in "${elements[@]@Q}"; do echo "  $element"; done;
}

# array_assert_empty <array-name>
function array_assert_empty() {
  local array=$1; shift 1;
  eval "local size=\${#$array[@]}";
  [[ $size -eq 0 ]] ||
    fail+ "$array: unexpected array size" \
        "expected: empty array" \
        "$(array_show $array "actual array")";
}

# array_assert_size <array-name> [(eq|ne|lt|le|gt|ge) <integer>]...
function array_assert_size() {
  local array=$1; shift 1;
  eval "local size=\${#$array[@]}";
  while (($#)); do
    local op=$1 n=$2; shift 2;
    eval "[[ $size -$op $n ]]" ||
      fail+ "$array: unexpected array size" \
          "expected: size $op $n" \
          "$(array_show $array "actual array")";
  done
}

# array_assert_element <array-name> <index>] <expected-element>
function array_assert_element() {
  local array=$1; index=$2; shift 2;
  eval "local size=\${#$array[@]}";
  eval "local elements=(\"\${$array[@]}\")";
  [[ $size -gt $((index)) ]] ||
    fail+ "$array: unexpected array size" \
        "expected element $((index)): ${1@Q}" \
        "$(array_show $array "actual array")";
  [[ "${elements[$index]}" = "$1" ]] ||
    fail+ "$array: unexpected array element $index" \
        "expected element: ${1@Q}" \
        "actual   element: ${elements[$index]@Q}" \
        "$(array_show $array "actual array")";
}

# array_assert <array-name> <expected-array-element>...
function array_assert() {
  local array=$1; shift 1;
  eval "local size=\${#$array[@]}";
  eval "local elements=(\"\${$array[@]}\")";
  [[ $size -eq $# ]] || {
    local expected_elements=("$@");
    fail+ "$array: unexpected array size" \
        "$(array_show expected_elements "expected array")" \
        "$(array_show $array "actual array")"; }
  local -i i=0;
  for ((;i<$#; i++)); do
    eval "[[ \"\${elements[i]}\" = \"\${$((i+1))}\" ]]" || {
      local expected_elements=("$@");
      fail+ "$array: unexpected array element $i" \
          "expected element: ${expected_elements[i]@Q}" \
          "actual   element: ${elements[i]@Q}" \
          "$(array_show expected_elements "expected array")" \
          "$(array_show $array "actual array")"; }
  done
}

# NAME
#
# check – Checks that a command behaves as expected.

# SYNOPSIS
#
# check <command-line>…

# INPUT VARIABLES
#
# - expected_status - integer: The command's expected exit status. If
#     unspecified and "expected_error" is specified, defaults to 1,
#     otherwise default to 0.
#
# - expected_error - array: The command's expected error lines. If
#     unspecified, defaults to an empty array.
#
# - expect_no_debug - boolean: Whether to expect no debug output.
#     Defaults to false.
#
# - expect_no_times - boolean: Whether to expect no times output.
#     Defaults to false.
#
# - expect_no_error - boolean: Whether to expect no error output.
#     Defaults to false.

# OUTPUT VARIABLES
#
# - output - array: Output lines (stdout + stderr).
#
# - output_debug - array: Debug output lines.
# - output_times - array: Times output lines.
# - output_error - array: Error output lines.
#
# - output_parameters - array: Parameters debug output lines.
# - output_prelude - array: Prelude run debug output lines.
# - output_command1 - array: First command run debug output lines.
# - output_command2 - array: Second command run debug output lines.
# - output_command3 - array: Third command run debug output lines.

# BEWARE: The code here is Bash code while the code in the test
# command is Zsh code.
function check() {
  # Run the command.
  local var env=();
  for var in ZBENCH_MULTIPLIER ZBENCH_TARGET_MS ZBENCH_BOTTOM_MS; do
    [[ ! -v $var ]] || eval "env+=($var=\"\$$var\")";
  done;
  echo "# Testing:" "${env[@]}" "${@@Q}";
  run "$@";

  if ((${expected_status:-0})); then
    assert_failure ${expected_status};
  elif [ -n "${expected_error[*]:-}" ]; then
    assert_failure 1;
  else
    assert_success;
  fi;

  # Split output into output_debug, output_times, and output_error.
  local -i n=0;
  output_debug=();
  output_times=();
  output_error=();
  while ((n < ${#lines[@]})); do
    local line="${lines[n++]}";
    case "$line" in
      $FG_GRN* ) output_times+=("$line");;
      $FG_RED* ) output_error+=("$line");;
      *        ) output_debug+=("$line");;
    esac;
  done;

  # Check that the output splits truly represent the original.
  assert_output "$(join "$NL" "${output_debug[@]}" "${output_times[@]}" "${output_error[@]}")";

  # Remove coloring.
  output_debug=("${output_debug[@]/#$FG_YLW}"); output_debug=("${output_debug[@]/%$FG_DEF}");
  output_times=("${output_times[@]/#$FG_GRN}"); output_times=("${output_times[@]/%$FG_DEF}");
  output_error=("${output_error[@]/#$FG_RED}"); output_error=("${output_error[@]/%$FG_DEF}");

  # Check that splits expected to be empty are indeed empty.
  ! ${expect_no_debug:-false} || array_assert_empty output_debug;
  ! ${expect_no_times:-false} || array_assert_empty output_times;
  ! ${expect_no_error:-false} || array_assert_empty output_error;

  # Check the expected error, if any.
  [[ -z "${expected_error[*]:-}" ]] || array_assert output_error "${expected_error[@]}";

  # Split output_debug into output_{parameters,prelude,command{1,2,3}}.
  local -i n=0;
  local section;
  for section in parameters prelude command1 command2 command3; do
    eval "output_$section=()";
    while ((n < ${#output_debug[@]})); do
      local line="${output_debug[n++]}";
      [[ -n "$line" ]] || break;
      eval "output_$section+=(\"\$line\")";
    done;
  done;

  # Check that the output_debug splits truly represent the original.
  array_assert output_debug "${expected_output_debug[@]}" \
      "${output_parameters[@]}" \
      "${output_parameters[@]+""}" \
      "${output_prelude[@]}" \
      "${output_prelude[@]+""}" \
      "${output_command1[@]}" \
      "${output_command1[@]+""}" \
      "${output_command2[@]}" \
      "${output_command2[@]+""}" \
      "${output_command3[@]}" \
      "${output_command3[@]+""}";
}

################################################################################

@test "immediate exit" {
  # - Tests that benchmarking immediately stops if the prelude and/or
  #   the command exit their shell. A prelude is only useful if the
  #   command can be run afterwards in the same shell, which is
  #   impossible if the prelude exits its shell. A command can only be
  #   benchmarked if it can be repeatedly run in a loop, which is
  #   impossible if the command exits its shell.

  # - Tests that shell exits triggered by the shell options -e and -u
  #   are caught.

  # - Tests that the error output and debug output report the exit
  #   status with which the prelude or command exited.

  expect_no_times=true;
  tests=(
    "exit,0"
    "exit 42,42"
    "return,0"
    "return 42,42"
    "set -e; undefined,127,(eval):1: command not found: undefined"
    "set -u; : \$undefined,1,(eval):1: undefined: parameter not set");
  for test in "${tests[@]}"; do
    IFS="," read command status_ stdout <<< "$test"; stdout=(${stdout:+"$stdout"});

    expected_error="$ZBENCH: The command triggered a shell exit with status $status_.";
    check $ZBENCH "$command";
    array_assert_empty output_debug;

    check $ZBENCH --debug "$command";
    array_assert output_prelude \
        "Running prelude..." \
        "...ended with exit status 0.";
    array_assert output_command1 \
        "Running command..." \
        "${stdout[@]}" \
        "...triggered a shell exit with status $status_.";
    array_assert_empty output_command2;
    array_assert_empty output_command3;

    expected_error="$ZBENCH: The prelude triggered a shell exit with status $status_.";
    check $ZBENCH --prelude "$command" echo hello;
    array_assert_empty output_debug;

    check $ZBENCH --debug --prelude "$command" echo hello;
    array_assert output_prelude \
        "Running prelude..." \
        "${stdout[@]}" \
        "...triggered a shell exit with status $status_.";
    array_assert_empty output_command1;
    array_assert_empty output_command2;
    array_assert_empty output_command3;
  done;
}

@test "delayed exit" {
  # - Tests that the debug output reports the output of the executed
  #   prelude and command(s) as well as the exit status with which
  #   they ended or exited.

  # - Tests (via the shared variable "n" and the exit status reported
  #   in the debug output) that the prelude and the command are run in
  #   the same (sub-)shell and that successive benchmarking iterations
  #   are run in independent (sub-)shells.

  for test in "1,eq 0" "2,eq 1" "3,eq 1" "4,eq 1" "50,eq 2" "1000,gt 2"; do
    IFS="," read runs times_constraint <<< "$test";

    prelude="n=0; f(){echo n=\$n; ((n<$runs)) || exit n; return $runs-n++}; f";
    expected_error="$ZBENCH: The command triggered a shell exit with status $((runs%256)).";

    check $ZBENCH --prelude "$prelude" -- f;
    array_assert_size output_times $times_constraint;
    array_assert_empty output_debug;

    check $ZBENCH --debug --prelude "$prelude" -- f;
    array_assert_size output_times $times_constraint;
    array_assert output_prelude \
        "Running prelude..." \
        "n=0" \
        "...ended with exit status $runs.";
    for n in 1 2 3; do
      if [[ $runs -gt $n ]]; then
        array_assert output_command$n \
            "Running command..." \
            "n=$n" \
            "...ended with exit status $((runs-n)).";
      elif [[ $runs -eq $n ]]; then
        array_assert output_command$n \
            "Running command..." \
            "n=$n" \
            "...triggered a shell exit with status $runs.";
      else
        array_assert_empty output_command$n;
      fi;
    done;
  done;
}

@test "parameters" {
  expected_status=1;

  ZBENCH_MULTIPLIER=111 ZBENCH_TARGET_MS=22222 ZBENCH_BOTTOM_MS=33 check $ZBENCH -d exit;
  array_assert output_parameters \
      "Multiplier : 111" \
      "Time target: 22222 ms" \
      "Time bottom: 33 ms" \
      "Prelude    : \"\"" \
      "Command    : \"exit\"";
  array_assert_empty output_times;
  array_assert output_error "$ZBENCH: The command triggered a shell exit with status 0.";

  check $ZBENCH -d -p "echo prelude" "echo command;" exit;
  array_assert output_parameters \
      "Multiplier : 4" \
      "Time target: 10000 ms" \
      "Time bottom: 10 ms" \
      "Prelude    : \"echo prelude\"" \
      "Command    : \"echo command; exit\"";
  array_assert_empty output_times;
  array_assert output_error "$ZBENCH: The command triggered a shell exit with status 0.";

  expected_status=0;

  ZBENCH_TARGET_MS=10 ZBENCH_BOTTOM_MS=1 check $ZBENCH -d;
  array_assert output_parameters \
      "Multiplier : 4" \
      "Time target: 10 ms" \
      "Time bottom: 1 ms" \
      "Prelude    : \"\"" \
      "Command    : \"\"";
  array_assert_size output_times gt 1;
  array_assert_empty output_error;
}

@test "prelude/command output" {
  expected_error="$ZBENCH: The command triggered a shell exit with status 0.";
  expect_no_times=true;

  check $ZBENCH -d -p "echo pre-out; echo pre-err >&2" "echo cmd-out;" "echo cmd-err >&2;" exit;
  array_assert output_prelude \
      "Running prelude..." \
      "pre-out" \
      "pre-err" \
      "...ended with exit status 0.";
  array_assert output_command1 \
      "Running command..." \
      "cmd-out" \
      "cmd-err" \
      "...triggered a shell exit with status 0.";

  check $ZBENCH -d -p "echo pre-err >&2; echo pre-out" "echo cmd-err >&2;" "echo cmd-out;" exit;
  array_assert output_prelude \
      "Running prelude..." \
      "pre-err" \
      "pre-out" \
      "...ended with exit status 0.";
  array_assert output_command1 \
      "Running command..." \
      "cmd-err" \
      "cmd-out" \
      "...triggered a shell exit with status 0.";
}

@test "times" {
  expect_no_debug=true;
  expect_no_error=true;

  ZBENCH_TARGET_MS=100 ZBENCH_BOTTOM_MS=5 check $ZBENCH echo hello;
  array_assert_size output_times gt 2;
  for ((i=1; i < ${#output_times[@]}; i++)); do
    pattern='^CPU/Clk: *(.+)/ *(.+) µs/run [(] *(.+)/ *(.+) s[)] *(.+)% Sys, Runs: (.+)$';
    [[ "${output_times[i]}" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i" \
          "expected pattern: ${pattern@Q}" \
          "actual   element: ${output_times[1]@Q}" \
          "$(array_show output_times "actual array")";

    cpu_run="${BASH_REMATCH[1]}";
    clk_run="${BASH_REMATCH[2]}";
    cpu_tot="${BASH_REMATCH[3]}";
    clk_tot="${BASH_REMATCH[4]}";
    sys="${BASH_REMATCH[5]}";
    runs="${BASH_REMATCH[6]}";

    pattern='^[0-9]{1,5}[.][0-9]{3}$';
    [[ "$cpu_run" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ cpu/run" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${cpu_run@Q}" \
          "$(array_show output_times "actual array")";
    [[ "$clk_run" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ clk/run" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${clk_run@Q}" \
          "$(array_show output_times "actual array")";

    pattern='^[0-9]{1,3}[.][0-9]{3}$';
    [[ "$cpu_tot" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ total cpu" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${cpu_tot@Q}" \
          "$(array_show output_times "actual array")";
    [[ "$clk_tot" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ total clk" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${clk_tot@Q}" \
          "$(array_show output_times "actual array")";

    pattern='^[0-9]{1,3}[.][0-9]{1}$';
    [[ "$sys" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ sys" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${sys@Q}" \
          "$(array_show output_times "actual array")";

    pattern='^[1-9][0-9]*$';
    [[ "$runs" =~ $pattern ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ runs" \
          "expected pattern: ${pattern@Q}" \
          "actual   value  : ${runs@Q}" \
          "$(array_show output_times "actual array")";

    [[ $runs -gt ${last_runs:-0} ]] ||
      fail+ "output_times[$i]: unexpected array element $i @ runs gt last_runs" \
          "expected value: gt ${last_runs:0}" \
          "actual   value: ${runs}" \
          "$(array_show output_times "actual array")";

    last_runs=$runs;
  done;

  cpu_tot_s=${cpu_tot#0.}; cpu_tot_s=${cpu_tot_s#0};
  [[ $cpu_tot_s -ge 80 && $cpu_tot_s -lt 120 ]] ||
    fail+ "output_times[$((i-1))]: unexpected array element $((i-1)) @ cpu_tot ~ 0.100" \
        "expected value: ge 0.080 && lt 0.120" \
        "actual   value: ${cpu_tot}" \
        "$(array_show output_times "actual array")";
}

@test "autoloaded function" {
  # check-zbench <prelude> <command>
  function check-zbench() {
    ZBENCH_TARGET_MS=10 ZBENCH_BOTTOM_MS=1 check \
        zsh -c "PATH=$ROOT/src/bin; FPATH=$ROOT/src/functions; . zbench.zsh; $1 ; zbench -d '$2'";
  }

  # Test that by default no function foo is defined.
  expected_status=0;
  check-zbench "" "foo";
  array_assert_element output_command1 1 "(eval):1: command not found: foo";
  array_assert_size output_times gt 1;
  array_assert_empty output_error;

  # Test that a function defined in the calling script can be called.
  expected_status=0;
  check-zbench "foo() {echo hello}" "foo";
  array_assert_element output_command1 1 "hello";
  array_assert_size output_times gt 1;
  array_assert_empty output_error;

  # Test that the shell options from the calling script are preserved.

  expected_status=0;
  check-zbench "set +e" "echo \$options[ERREXIT]; foo";
  array_assert output_command1 \
      "Running command..." \
      "off" \
      "(eval):1: command not found: foo" \
      "...ended with exit status 127.";
  array_assert_size output_times gt 1;
  array_assert_empty output_error;

  expected_status=1;
  check-zbench "set -e" "echo \$options[ERREXIT]; foo";
  array_assert output_command1 \
      "Running command..." \
      "on" \
      "(eval):1: command not found: foo" \
      "...triggered a shell exit with status 127.";
  array_assert_empty output_times;
  array_assert output_error "zsh: The command triggered a shell exit with status 127.";

  expected_status=0;
  check-zbench "set +u" "echo \$options[UNSET]; : \$foo";
  array_assert output_command1 \
      "Running command..." \
      "on" \
      "...ended with exit status 0.";
  array_assert_size output_times gt 1;
  array_assert_empty output_error;

  expected_status=1;
  check-zbench "set -u" "echo \$options[UNSET]; : \$foo";
  array_assert output_command1 \
      "Running command..." \
      "off" \
      "(eval):1: foo: parameter not set" \
      "...triggered a shell exit with status 1.";
  array_assert_empty output_times;
  array_assert output_error "zsh: The command triggered a shell exit with status 1.";
}

################################################################################
