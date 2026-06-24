#!/usr/bin/env bash

pg2s3_validate_required_config() {
  local missing=()
  local required_vars=(
    PGHOST
    PGPORT
    PGUSER
    PGPASSWORD
    AWS_S3_BUCKET
  )
  local var_name

  for var_name in "${required_vars[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("${var_name}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    log_error "Missing required environment variables: ${missing[*]}"
    return 1
  fi
}

pg2s3_validate_dependencies() {
  local missing=()
  local dependency

  for dependency in psql pg_dump aws; do
    if ! command -v "${dependency}" >/dev/null 2>&1; then
      missing+=("${dependency}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    log_error "Missing required command(s): ${missing[*]}"
    return 1
  fi
}

pg2s3_validate_runtime() {
  pg2s3_validate_required_config
  pg2s3_validate_dependencies
}
