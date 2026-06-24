#!/usr/bin/env bash

pg2s3_log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

pg2s3_log_write() {
  local level="$1"
  local message="$2"
  local line

  line="[$(pg2s3_log_timestamp)] [${level}] ${message}"

  if [[ -n "${PG2S3_LOG_FILE:-}" ]]; then
    printf '%s\n' "${line}" | tee -a "${PG2S3_LOG_FILE}"
  else
    printf '%s\n' "${line}"
  fi
}

log_info() {
  pg2s3_log_write "INFO" "$*"
}

log_warn() {
  pg2s3_log_write "WARN" "$*"
}

log_error() {
  pg2s3_log_write "ERROR" "$*" >&2
}
