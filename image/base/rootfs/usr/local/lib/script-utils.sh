#!/bin/bash

function help() {
  sed -rn 's/^### ?//;T;p' "$0"
}

function join_by() {
  local d=$1
  shift
  local f=$1
  shift
  printf %s "$f" "${@/#/$d}"
}

function error_help() {
  local -r msg="$1"
  echo "[ERROR] $msg" >&2
  echo
  help
  exit 2
}

function error_exit() {
  local -r msg="$1" rc=${2:-1}
  echo "[ERR] $msg" >&2
  exit $rc
}

## Simple function to retry command
## $1   - max attempts
## $2.. - the command
function retry() {
  local -r -i max_attempts="$1"
  shift
  local -i attempt=0

  until "$@"; do
    command_status=$?
    if ((attempt == max_attempts)); then
      return $command_status
    else
      ((attempt += 1))
      echo "[ERROR] command failed. Retry in $attempt seconds..."
      sleep $attempt
    fi
  done

  true
}
