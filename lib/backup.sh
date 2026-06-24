#!/usr/bin/env bash

PG2S3_WORK_DIR=""

cleanup() {
  if [[ -z "${PG2S3_WORK_DIR:-}" || ! -d "${PG2S3_WORK_DIR}" ]]; then
    return 0
  fi

  if pg2s3_bool_is_true "${PG2S3_KEEP_LOCAL_DUMPS:-false}"; then
    log_warn "Keeping local dumps in temporary directory: ${PG2S3_WORK_DIR}"
    return 0
  fi

  rm -rf "${PG2S3_WORK_DIR}"
  log_info "Cleaned up temporary directory"
}

pg2s3_create_work_dir() {
  if [[ -n "${PG2S3_TEMP_DIR:-}" ]]; then
    mkdir -p "${PG2S3_TEMP_DIR}"
    PG2S3_WORK_DIR="$(mktemp -d "${PG2S3_TEMP_DIR%/}/pg2s3.XXXXXXXXXX")"
  else
    PG2S3_WORK_DIR="$(mktemp -d)"
  fi

  log_info "Created temporary directory: ${PG2S3_WORK_DIR}"
}

pg2s3_backup_database() {
  local db_name="$1"
  local timestamp="$2"
  local safe_db_name
  local dump_file

  safe_db_name="$(pg2s3_sanitize_s3_component "${db_name}")"
  dump_file="${PG2S3_WORK_DIR}/${timestamp}_${safe_db_name}.dump"

  log_info "Starting dump: ${db_name}"
  if ! pg2s3_dump_database "${db_name}" "${dump_file}"; then
    log_error "Dump failed: ${db_name}"
    return 1
  fi
  log_info "Dump completed: ${db_name}"

  log_info "Uploading dump: ${db_name}"
  if ! pg2s3_upload_dump "${dump_file}"; then
    log_error "Upload failed: ${db_name}"
    return 1
  fi
  log_info "Upload completed: ${db_name}"
}

pg2s3_backup() {
  local start_epoch
  local timestamp
  local processed=0
  local succeeded=0
  local failed=0
  local db_name
  local duration

  start_epoch="$(date '+%s')"
  timestamp="$(pg2s3_timestamp)"

  trap cleanup EXIT

  log_info "Starting backup"
  pg2s3_validate_runtime
  pg2s3_log_effective_config
  pg2s3_create_work_dir
  pg2s3_discover_databases

  if ((${#DATABASES[@]} == 0)); then
    log_warn "No databases found for backup"
  fi

  for db_name in "${DATABASES[@]}"; do
    processed=$((processed + 1))

    if pg2s3_backup_database "${db_name}" "${timestamp}"; then
      succeeded=$((succeeded + 1))
    else
      failed=$((failed + 1))
    fi
  done

  duration="$(pg2s3_duration_seconds "${start_epoch}")"

  log_info "Backup summary: processed=${processed} success=${succeeded} failed=${failed} duration_seconds=${duration}"
  printf 'Processed: %s\nSuccess: %s\nFailed: %s\nDuration: %ss\n' "${processed}" "${succeeded}" "${failed}" "${duration}"

  if ((failed > 0)); then
    return 1
  fi

  return 0
}
