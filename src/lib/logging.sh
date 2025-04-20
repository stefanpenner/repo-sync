#!/usr/bin/env bash

# Guard against multiple sourcing
if [[ -n "${_LOGGING_SH_SOURCED:-}" ]]; then
  return 0
fi
_LOGGING_SH_SOURCED=1

# Log levels - only declare if not already set
if [[ -z "${LOG_LEVEL_DEBUG+x}" ]]; then
  readonly LOG_LEVEL_DEBUG=0
  readonly LOG_LEVEL_INFO=1
  readonly LOG_LEVEL_WARN=2
  readonly LOG_LEVEL_ERROR=3
fi

# Current log level (default to INFO)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO} # default to INFO for now

# Logging function
# Usage: log <level> <message>
log() {
  local level=$1
  shift
  local message=$*
  local timestamp
  local caller_file
  local caller_line
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  caller_file=$(basename "${BASH_SOURCE[1]}")
  caller_line=${BASH_LINENO[0]}

  # Only log if the message level is >= current log level
  if [[ $level -ge $LOG_LEVEL ]]; then
    case $level in
    "$LOG_LEVEL_DEBUG") echo "[$timestamp] DEBUG: $message $caller_file:$caller_line" >&2 ;;
    "$LOG_LEVEL_INFO") echo "[$timestamp] INFO: $message $caller_file:$caller_line" >&2 ;;
    "$LOG_LEVEL_WARN") echo "[$timestamp] WARN: $message $caller_file:$caller_line: " >&2 ;;
    "$LOG_LEVEL_ERROR") echo "[$timestamp] ERROR: $message $caller_file:$caller_line: " >&2 ;;
    esac
  fi
}

# Error handling function
# Usage: error <message> [exit_code]
error() {
  local message=$1
  local exit_code=${2:-1}
  log $LOG_LEVEL_ERROR "$message"
  exit $exit_code
}