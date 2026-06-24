#!/usr/bin/env bash

pg2s3_upload_dump() {
  local dump_file="$1"
  local destination_prefix

  destination_prefix="$(pg2s3_s3_destination_prefix)"

  aws s3 cp "${dump_file}" "${destination_prefix}"
}

pg2s3_list_backups_interface_note() {
  # Reserved lightweight interface anchor for a future `pg2s3 list` command.
  pg2s3_s3_destination_prefix
}
