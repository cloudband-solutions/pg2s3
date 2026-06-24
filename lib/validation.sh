#!/usr/bin/env bash

pg2s3_validate_required_config() {
  local missing=()
  local required_vars=(
    PGHOST
    PGPORT
    PGUSER
    PGPASSWORD
    AWS_REGION
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
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

pg2s3_validate_aws_credentials() {
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    log_error "AWS credentials are not available to the current user."
    log_error "Set AWS_REGION, AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY in the environment used to run pg2s3."
    return 1
  fi
}

pg2s3_validate_log_file() {
  if [[ -z "${PG2S3_LOG_FILE:-}" ]]; then
    return 0
  fi

  if ! pg2s3_log_file_is_writable "${PG2S3_LOG_FILE}"; then
    log_error "Log file is not writable by current user: ${PG2S3_LOG_FILE}"
    log_error "Fix permissions or unset PG2S3_LOG_FILE. Example: sudo touch ${PG2S3_LOG_FILE}; sudo chown ubuntu:ubuntu ${PG2S3_LOG_FILE}; sudo chmod 640 ${PG2S3_LOG_FILE}"
    return 1
  fi
}

pg2s3_validate_runtime() {
  pg2s3_validate_required_config
  pg2s3_validate_log_file
  pg2s3_validate_dependencies
  pg2s3_validate_aws_credentials
}
