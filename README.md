# pg2s3

`pg2s3` is a production-oriented Bash command-line utility for backing up PostgreSQL databases to Amazon S3. It is intended for Linux servers, especially AWS EC2 instances, and is designed to run cleanly from cron.

## Features

- Discovers PostgreSQL databases automatically.
- Excludes templates and configurable additional databases.
- Creates PostgreSQL custom-format dumps with `pg_dump -Fc`.
- Stores dumps in a temporary working directory.
- Uploads dumps to Amazon S3 with the AWS CLI.
- Produces timestamped structured logs.
- Writes logs to stdout and optionally to a configured log file.
- Continues processing remaining databases if one database fails.
- Cleans up temporary files by default.
- Uses environment variables for all configuration.
- Keeps command structure ready for future `restore`, `verify`, `cleanup`, and `list` commands.

## Requirements

- Bash
- PostgreSQL client tools: `psql`, `pg_dump`
- AWS CLI v2, or an AWS CLI version compatible with `aws s3 cp`
- Network access from the server to PostgreSQL and S3
- AWS credentials supplied by an IAM role, instance profile, environment variables, or AWS config files

## Installation

Clone or copy this repository to the server, then install the command:

```bash
sudo install -d /opt/pg2s3 /usr/local/bin
sudo cp -R bin lib examples cron README.md LICENSE /opt/pg2s3/
sudo ln -sf /opt/pg2s3/bin/pg2s3 /usr/local/bin/pg2s3
sudo chmod +x /opt/pg2s3/bin/pg2s3
```

Ubuntu dependency installation:

```bash
sudo apt update
sudo apt install -y postgresql-client awscli
```

Confirm dependencies:

```bash
command -v psql
command -v pg_dump
command -v aws
```

## Configuration

Create an environment file such as `/etc/pg2s3.env`:

```bash
sudo cp examples/pg2s3.env.example /etc/pg2s3.env
sudo editor /etc/pg2s3.env
```

If backups will run as the `ubuntu` user, make the file readable by `ubuntu` and not readable by other users:

```bash
sudo chown ubuntu:ubuntu /etc/pg2s3.env
sudo chmod 600 /etc/pg2s3.env
```

Alternatively, keep `root` as the owner and grant read access to the `ubuntu` group:

```bash
sudo chown root:ubuntu /etc/pg2s3.env
sudo chmod 640 /etc/pg2s3.env
```

Required variables:

| Variable | Description |
| --- | --- |
| `PGHOST` | PostgreSQL host |
| `PGPORT` | PostgreSQL port |
| `PGUSER` | PostgreSQL user |
| `PGPASSWORD` | PostgreSQL password |
| `AWS_S3_BUCKET` | Destination S3 bucket name |

Optional variables:

| Variable | Default | Description |
| --- | --- | --- |
| `AWS_S3_PREFIX` | `postgres` | S3 prefix for uploaded dumps |
| `AWS_REGION` | unset | AWS region exported as `AWS_REGION` and `AWS_DEFAULT_REGION` |
| `PG2S3_RETENTION_DAYS` | unset | Reserved for future cleanup support |
| `PG2S3_LOG_FILE` | unset | If set, logs are written to stdout and this file |
| `PG2S3_EXCLUDED_DATABASES` | unset | Extra databases to exclude, comma or space separated |
| `PG2S3_KEEP_LOCAL_DUMPS` | `false` | Keep temporary dumps after completion when set to `true` |
| `PG2S3_TEMP_DIR` | system default | Parent directory used for the temporary working directory |

Example:

```bash
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=changeme

AWS_S3_BUCKET=my-backups
AWS_S3_PREFIX=postgres
AWS_REGION=ap-southeast-1

PG2S3_LOG_FILE=/var/log/pg2s3.log
PG2S3_EXCLUDED_DATABASES=postgres,maintenance
PG2S3_KEEP_LOCAL_DUMPS=false
```

`pg2s3` never logs `PGPASSWORD` or other sensitive values.

## Usage

Run a backup:

```bash
set -a
. /etc/pg2s3.env
set +a
pg2s3 backup
```

Test the same flow explicitly as the `ubuntu` user:

```bash
sudo -iu ubuntu bash -lc 'set -a; . /etc/pg2s3.env; set +a; /usr/local/bin/pg2s3 backup'
```

The only implemented command is:

```bash
pg2s3 backup
```

The command dispatcher reserves future command names:

```bash
pg2s3 restore
pg2s3 verify
pg2s3 cleanup
pg2s3 list
```

These commands intentionally return a clear “not implemented” error for now.

## Backup Workflow

The `backup` command:

1. Loads environment configuration and defaults.
2. Validates required environment variables.
3. Validates that `psql`, `pg_dump`, and `aws` exist.
4. Creates a temporary working directory with `mktemp -d`.
5. Discovers databases with:

```sql
SELECT datname
FROM pg_database
WHERE datistemplate = false
AND datallowconn = true
ORDER BY datname;
```

6. Excludes `template0`, `template1`, and configured exclusions.
7. Dumps each database with PostgreSQL custom format:

```bash
pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -Fc -f "$DUMP_FILE"
```

8. Verifies that each dump file exists and is not empty.
9. Uploads each dump with `aws s3 cp`.
10. Continues to the next database if one database fails.
11. Prints a summary and exits with `0` for complete success or `1` for partial or total failure.
12. Removes the temporary directory unless `PG2S3_KEEP_LOCAL_DUMPS=true`.

Dump filenames use this format:

```text
20260624_143000_app.dump
```

Uploads go to:

```text
s3://AWS_S3_BUCKET/AWS_S3_PREFIX/
```

## Logging

Logs are structured as:

```text
[2026-06-24 14:30:00] [INFO] Starting backup
[2026-06-24 14:31:10] [INFO] Dump completed: app
[2026-06-24 14:31:25] [ERROR] Upload failed: analytics
```

If `PG2S3_LOG_FILE` is set, logs are written to stdout and appended to the configured file.

## Cron Setup

For a user crontab, install the job as `ubuntu`:

```bash
sudo crontab -u ubuntu -e
```

Add:

```cron
0 2 * * * set -a; . /etc/pg2s3.env; set +a; /usr/local/bin/pg2s3 backup >> /var/log/pg2s3.log 2>&1
```

Make sure the `ubuntu` user can write the configured log file or the redirected cron log. One simple setup is:

```bash
sudo touch /var/log/pg2s3.log
sudo chown ubuntu:ubuntu /var/log/pg2s3.log
sudo chmod 640 /var/log/pg2s3.log
```

Test the cron command as `ubuntu` before waiting for the scheduled run:

```bash
sudo -iu ubuntu bash -lc 'set -a; . /etc/pg2s3.env; set +a; /usr/local/bin/pg2s3 backup >> /var/log/pg2s3.log 2>&1'
sudo tail -n 100 /var/log/pg2s3.log
```

To install the included cron file into the `ubuntu` user's crontab:

```bash
sudo crontab -u ubuntu cron/pg2s3.cron
sudo crontab -u ubuntu -l
```

The same cron line is included in [cron/pg2s3.cron](cron/pg2s3.cron).

## IAM Role Recommendations

Use IAM roles instead of long-lived AWS access keys whenever possible. On EC2, attach an instance profile with least-privilege S3 permissions.

Minimum write-oriented policy shape:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::my-backups/postgres/*"
    }
  ]
}
```

For future list, restore, verification, or cleanup commands, add only the required permissions such as `s3:ListBucket`, `s3:GetObject`, or `s3:DeleteObject`.

## AWS Recommendations

- Store backups in a dedicated S3 bucket.
- Restrict S3 permissions using least privilege.
- Enable S3 server-side encryption.
- Enable S3 versioning.
- Enable S3 lifecycle rules for cost and retention management.
- Consider S3 Object Lock when regulatory retention is required.
- Monitor backup failures with CloudWatch, cron mail, or your server monitoring system.

## Security Recommendations

- Prefer IAM roles or instance profiles over static AWS access keys.
- Keep `/etc/pg2s3.env` readable only by trusted users.
- Use a PostgreSQL role with the minimum permissions needed for backups.
- Do not place secrets directly in crontab lines.
- Do not log environment files.
- Rotate PostgreSQL credentials according to your operational policy.
- Consider server-side encryption with a customer-managed KMS key for sensitive workloads.

## Retention Support Design

`PG2S3_RETENTION_DAYS` is loaded but not acted on yet. The command structure reserves:

```bash
pg2s3 cleanup
```

A future cleanup command can reuse the S3 prefix interface in `lib/s3.sh`, list objects below the configured prefix, compare object timestamps to `PG2S3_RETENTION_DAYS`, and delete expired objects after validating permissions and configuration.

## Future Restore Design

Restore is intentionally not implemented yet. The project is structured so a future:

```bash
pg2s3 restore
```

can reuse configuration, validation, logging, and S3 helpers to list available backups, download a selected dump, and execute `pg_restore` with clear safety checks.

## Troubleshooting

Missing environment variable:

```text
[2026-06-24 14:30:00] [ERROR] Missing required environment variables: PGHOST PGPASSWORD
```

Fix the missing variable in `/etc/pg2s3.env`, reload the environment, and rerun.

Missing dependency:

```text
[2026-06-24 14:30:00] [ERROR] Missing required command(s): pg_dump aws
```

Install PostgreSQL client tools and the AWS CLI.

PostgreSQL authentication failure:

- Verify `PGHOST`, `PGPORT`, `PGUSER`, and `PGPASSWORD`.
- Confirm the server accepts connections from the backup host.
- Confirm the PostgreSQL role can connect to the databases being backed up.

S3 upload failure:

- Verify `AWS_S3_BUCKET` and `AWS_S3_PREFIX`.
- Confirm the EC2 instance role or AWS credentials allow `s3:PutObject`.
- Confirm the configured region is correct.
- Run `aws sts get-caller-identity` to verify the active AWS identity.

Local disk pressure:

- Set `PG2S3_TEMP_DIR` to a filesystem with enough free space.
- Ensure `PG2S3_KEEP_LOCAL_DUMPS=false` for normal cron operation.

## Example Backup Session

```text
[2026-06-24 14:30:00] [INFO] Starting backup
[2026-06-24 14:30:00] [INFO] Created temporary directory: /tmp/tmp.P4TnUPsO3R
[2026-06-24 14:30:01] [INFO] Discovering PostgreSQL databases
[2026-06-24 14:30:01] [INFO] Discovered 3 database(s) eligible for backup
[2026-06-24 14:30:02] [INFO] Starting dump: app
[2026-06-24 14:31:10] [INFO] Dump completed: app
[2026-06-24 14:31:11] [INFO] Uploading dump: app
[2026-06-24 14:31:25] [INFO] Upload completed: app
[2026-06-24 14:34:10] [INFO] Backup summary: processed=3 success=3 failed=0 duration_seconds=250
Processed: 3
Success: 3
Failed: 0
Duration: 250s
```

## Test Procedure

Create a test database:

```bash
createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" pg2s3_test
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d pg2s3_test -c 'CREATE TABLE backup_check(id int primary key, note text);'
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d pg2s3_test -c "INSERT INTO backup_check VALUES (1, 'ok');"
```

Run a backup while keeping local dumps:

```bash
export PG2S3_KEEP_LOCAL_DUMPS=true
pg2s3 backup
```

Verify:

```bash
aws s3 ls "s3://${AWS_S3_BUCKET}/${AWS_S3_PREFIX}/"
```

Confirm the output includes a timestamped `pg2s3_test.dump` file.

Verify the local dump exists in the temporary directory printed by the logs. Then run again with cleanup enabled:

```bash
export PG2S3_KEEP_LOCAL_DUMPS=false
pg2s3 backup
```

Confirm the logs show `Cleaned up temporary directory`.

Remove the test database when finished:

```bash
dropdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" pg2s3_test
```
