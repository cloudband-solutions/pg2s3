#!/usr/bin/env bash

pg2s3_log_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

PG2S3_LOG_FILE_WARNING_EMITTED="false"

pg2s3_log_file_is_writable() {
  local log_file="${1:-}"
  local log_dir

  [[ -n "${log_file}" ]] || return 0

  if [[ -e "${log_file}" ]]; then
    [[ -f "${log_file}" && -w "${log_file}" ]]
    return
  fi

  log_dir="$(dirname "${log_file}")"
  [[ -d "${log_dir}" && -w "${log_dir}" ]]
}

pg2s3_warn_log_file_unwritable_once() {
  local log_file="$1"

  if [[ "${PG2S3_LOG_FILE_WARNING_EMITTED}" == "true" ]]; then
    return 0
  fi

  PG2S3_LOG_FILE_WARNING_EMITTED="true"
  printf '[%s] [WARN] Log file is not writable by current user; continuing with stdout only: %s\n' "$(pg2s3_log_timestamp)" "${log_file}" >&2
}

pg2s3_log_write() {
  local level="$1"
  local message="$2"
  local line

  line="[$(pg2s3_log_timestamp)] [${level}] ${message}"

  printf '%s\n' "${line}"

  if [[ -n "${PG2S3_LOG_FILE:-}" ]]; then
    if pg2s3_log_file_is_writable "${PG2S3_LOG_FILE}"; then
      if ! printf '%s\n' "${line}" >>"${PG2S3_LOG_FILE}"; then
        pg2s3_warn_log_file_unwritable_once "${PG2S3_LOG_FILE}"
      fi
    else
      pg2s3_warn_log_file_unwritable_once "${PG2S3_LOG_FILE}"
    fi
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
