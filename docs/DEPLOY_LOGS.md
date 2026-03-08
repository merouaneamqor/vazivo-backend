# Deployment & log notes

## ActiveRecord::ConcurrentMigrationError

**Message:** `Cannot run migrations because another migration process is currently running.`

**Cause:** More than one process tried to run `db:migrate` / `db:prepare` at the same time. Rails uses a database advisory lock so only one migrator runs.

**What we do:**
- The **api** container uses `bin/docker-entrypoint.sh`, which runs `db:prepare` with retries (every 5s, up to 12 attempts). If another process holds the lock, we wait and retry instead of failing.
- **Avoid** running `rails db:migrate` (or `db:prepare`) manually while the api container is starting. If you must, run it once the api is up, or stop the api first.

**Production:** Prefer running migrations in a single one-off step before deploying new app instances (e.g. a release task or a dedicated migrate job), and do **not** run `db:prepare` from every app/worker process on boot. Then you can remove the migration step from the app startup.

---

## PostgreSQL: "cached plan must not change result type"

**Cause:** A connection had prepared (cached) a query; then the table schema changed (e.g. a migration added/removed columns), and the same connection ran the query again. The cached plan no longer matches the new result type.

**Mitigation:**
- Run migrations **before** new app code serves traffic, and restart app servers after migrations so connections are new.
- If you see this often with long-lived connections, you can set `prepared_statements: false` for the database adapter in `config/database.yml` (trade-off: slightly more work per query).

---

## PostgreSQL: "database system was not properly shut down"

**Cause:** The database process was stopped abruptly (e.g. container kill, host reboot). On next start, PostgreSQL runs automatic recovery from WAL.

**Action:** Usually none. If recovery completes and the server is "ready to accept connections", you’re good. If you see repeated recovery or errors, check disk and avoid killing the DB process forcefully.

---

## CarrierWave / Cloudinary: "#filename method didn't return value after storing"

**Cause:** The uploader’s `#filename` is often guarded with `if original_filename` for legacy reasons; CarrierWave 3.x expects a return value after storing.

**Mitigation:** In the uploader class, ensure `#filename` returns a value (e.g. `super` or the stored filename) after storing. See: https://github.com/carrierwaveuploader/carrierwave/issues/2708
