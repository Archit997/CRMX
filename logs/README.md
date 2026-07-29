# Runtime logs

Local backend logs are written to `app.log` in this directory when
`LOG_TO_FILE=true`. Log files rotate according to `LOG_MAX_BYTES` and
`LOG_BACKUP_COUNT` and are ignored by Git.

Hosted deployments should use `LOG_FORMAT=json` and `LOG_TO_FILE=false`, then
send standard output to the hosting platform's log collector.
