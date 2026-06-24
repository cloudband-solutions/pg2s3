#!/usr/bin/env bash

pg2s3_bool_is_true() {
  local value="${1:-}"

  case "${value,,}" in
    1 | true | yes | y | on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pg2s3_timestamp() {
  date '+%Y%m%d_%H%M%S'
}

pg2s3_duration_seconds() {
  local start_epoch="$1"
  local end_epoch

  end_epoch="$(date '+%s')"
  printf '%s\n' "$((end_epoch - start_epoch))"
}

pg2s3_trim_slashes() {
  local value="${1:-}"

  value="${value#/}"
  value="${value%/}"
  printf '%s\n' "${value}"
}

pg2s3_sanitize_s3_component() {
  local value="$1"

  # Keep database-derived object names predictable without losing readability.
  printf '%s\n' "${value//[^A-Za-z0-9_.-]/_}"
}

pg2s3_array_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done

  return 1
}
