# Railway PostgreSQL logs: "not properly shut down" and "invalid record length"

When your Railway **PostgreSQL** service restarts (deploy, scale, or platform restart), you may see log lines like:

- `database system was interrupted; last known up at ...`
- `database system was not properly shut down; automatic recovery in progress`
- `invalid record length at 0/...: expected at least 24, got 0`
- `redo done at ...`
- `checkpoint complete`
- `database system is ready to accept connections`

## Do you need to fix anything?

**Usually no.** These messages mean:

1. The database was stopped without a clean shutdown (normal when a container is stopped or restarted).
2. PostgreSQL ran **automatic recovery** on startup.
3. The "invalid record length" line is often a truncated WAL record at the end of the log; recovery skips it and continues.
4. **"database system is ready to accept connections"** means recovery finished and the DB is healthy.

So the database has already "fixed" itself. No data loss is implied.

## What you can do in your app

1. **Use a readiness check**  
   The backend exposes `GET /up/ready`, which returns 200 only when the database is connectable. If Railway supports a **readiness probe**, point it at `https://your-api.railway.app/up/ready`. Then the platform will not send traffic to your app until Postgres has finished recovery.

2. **Liveness vs readiness**  
   - **Liveness** (e.g. `GET /up`): use for "is the process alive?". Keep this fast and without DB, so the container isn’t killed during boot.  
   - **Readiness** (e.g. `GET /up/ready`): use for "can we accept traffic?". This checks DB so traffic is held until Postgres is ready.

3. **Graceful shutdown**  
   Your Rails app (Puma) already handles SIGTERM. When Railway stops the **web** service, it will shut down cleanly. The PostgreSQL service is managed by Railway; we can’t change how it is stopped, so "not properly shut down" may still appear after restarts.

## If you see real errors

If after startup you see repeated connection errors, timeouts, or "database system is not ready to accept connections", then:

- Check that `DATABASE_URL` (or your DB env vars) for the **web** service point at the **PostgreSQL** service.
- In the Railway dashboard, confirm the PostgreSQL service is running and that the volume is mounted.
- Use the Railway CLI: `railway run bundle exec rails db:version` (from the backend directory) to confirm the app can connect.
