#!/usr/bin/env bash

PG2S3_DEFAULT_S3_PREFIX="postgres"

pg2s3_load_config() {
  AWS_S3_PREFIX="${AWS_S3_PREFIX:-${PG2S3_DEFAULT_S3_PREFIX}}"
  PG2S3_RETENTION_DAYS="${PG2S3_RETENTION_DAYS:-}"
  PG2S3_LOG_FILE="${PG2S3_LOG_FILE:-}"
  PG2S3_EXCLUDED_DATABASES="${PG2S3_EXCLUDED_DATABASES:-}"
  PG2S3_KEEP_LOCAL_DUMPS="${PG2S3_KEEP_LOCAL_DUMPS:-false}"
  PG2S3_TEMP_DIR="${PG2S3_TEMP_DIR:-}"

  if [[ -n "${AWS_REGION:-}" ]]; then
    export AWS_REGION
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
  fi

  export PGPASSWORD="${PGPASSWORD:-}"
}

pg2s3_sensitive_name() {
  local name="$1"

  case "${name}" in
    *PASSWORD* | *SECRET* | *TOKEN* | *KEY*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pg2s3_mask_value() {
  local name="$1"
  local value="${2:-}"

  if [[ -z "${value}" ]]; then
    printf '<empty>\n'
  elif pg2s3_sensitive_name "${name}"; then
    printf '<set>\n'
  else
    printf '%s\n' "${value}"
  fi
}

pg2s3_s3_destination_prefix() {
  local normalized_prefix

  normalized_prefix="$(pg2s3_trim_slashes "${AWS_S3_PREFIX}")"
  if [[ -n "${normalized_prefix}" ]]; then
    printf 's3://%s/%s/\n' "${AWS_S3_BUCKET}" "${normalized_prefix}"
  else
    printf 's3://%s/\n' "${AWS_S3_BUCKET}"
  fi
}

pg2s3_log_effective_config() {
  log_info "Configuration: PGHOST=$(pg2s3_mask_value PGHOST "${PGHOST:-}") PGPORT=$(pg2s3_mask_value PGPORT "${PGPORT:-}") PGUSER=$(pg2s3_mask_value PGUSER "${PGUSER:-}") AWS_S3_BUCKET=$(pg2s3_mask_value AWS_S3_BUCKET "${AWS_S3_BUCKET:-}") AWS_S3_PREFIX=$(pg2s3_mask_value AWS_S3_PREFIX "${AWS_S3_PREFIX:-}") AWS_REGION=$(pg2s3_mask_value AWS_REGION "${AWS_REGION:-}")"
}
