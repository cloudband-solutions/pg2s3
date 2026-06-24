#!/usr/bin/env bash

DATABASES=()
EXCLUDED_DATABASES=()

pg2s3_build_excluded_databases() {
  EXCLUDED_DATABASES=(template0 template1)

  local raw="${PG2S3_EXCLUDED_DATABASES:-}"
  local normalized
  local db_name

  normalized="${raw//,/ }"
  # shellcheck disable=SC2206
  local configured_exclusions=(${normalized})

  for db_name in "${configured_exclusions[@]}"; do
    if [[ -n "${db_name}" ]] && ! pg2s3_array_contains "${db_name}" "${EXCLUDED_DATABASES[@]}"; then
      EXCLUDED_DATABASES+=("${db_name}")
    fi
  done
}

pg2s3_discover_databases() {
  DATABASES=()
  pg2s3_build_excluded_databases

  local query
  local db_name
  local discovered=()
  local query_output

  query="SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true ORDER BY datname;"

  log_info "Discovering PostgreSQL databases"

  if ! query_output="$(
    psql \
      -h "${PGHOST}" \
      -p "${PGPORT}" \
      -U "${PGUSER}" \
      -d postgres \
      -At \
      -c "${query}"
  )"; then
    log_error "Failed to discover PostgreSQL databases"
    return 1
  fi

  while IFS= read -r db_name; do
    [[ -n "${db_name}" ]] || continue
    discovered+=("${db_name}")
  done <<<"${query_output}"

  for db_name in "${discovered[@]}"; do
    if pg2s3_array_contains "${db_name}" "${EXCLUDED_DATABASES[@]}"; then
      log_info "Skipping excluded database: ${db_name}"
      continue
    fi
    DATABASES+=("${db_name}")
  done

  log_info "Discovered ${#DATABASES[@]} database(s) eligible for backup"
}

pg2s3_dump_database() {
  local db_name="$1"
  local dump_file="$2"

  pg_dump \
    -h "${PGHOST}" \
    -p "${PGPORT}" \
    -U "${PGUSER}" \
    -d "${db_name}" \
    -Fc \
    -f "${dump_file}"

  if [[ ! -s "${dump_file}" ]]; then
    log_error "Dump file was not created or is empty: ${dump_file}"
    return 1
  fi
}
