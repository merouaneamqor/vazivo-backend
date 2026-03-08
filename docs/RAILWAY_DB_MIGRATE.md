# Fix: Connection refused during `db:migrate` on Railway (staging)

## The error

You may see in Sentry or deploy logs:

```text
PG::ConnectionBad: connection to server at "10.163.103.190", port 5432 failed: Connection refused
ActiveRecord::ConnectionNotEstablished: connection to server at "10.163.103.190", port 5432 failed: Connection refused
```

This happens when **`rake db:migrate` runs in a context that cannot reach the database’s private IP** (e.g. Railway’s pre-deploy step, which does not have access to the private network).

## Root cause

- **DATABASE_URL** is set to the **internal** Postgres URL (host like `10.x.x.x` or `postgres.railway.internal`).
- The **pre-deploy command** runs migrations with `DATABASE_URL="${DATABASE_PUBLIC_URL}"` (see `railway.toml`). If **DATABASE_PUBLIC_URL** is set to the same internal URL (or is empty), the migrate step still tries to connect to the private host and gets **Connection refused**.

## Fix

**Use the public Postgres URL for migrations.**

1. In your **Railway project**, open the **Postgres** service (or the service that provides the database).
2. In **Variables** or **Connect**, find the **public** connection URL. It usually has a host like `*.proxy.rlwy.net` or `*.railway.app`, **not** `10.x.x.x` or `postgres.railway.internal`.
3. In the **backend (web) service** that runs migrations, set:
   - **DATABASE_PUBLIC_URL** = that **public** URL (e.g. `postgresql://user:pass@maglev.proxy.rlwy.net:36861/railway`).
   - Keep **DATABASE_URL** as the internal URL (Railway often sets this automatically when you link Postgres). The app at runtime will use the internal URL; only the pre-deploy migrate step uses **DATABASE_PUBLIC_URL**.

**Wrong (causes the error):**

- `DATABASE_URL="${{Postgres.DATABASE_URL}}"`
- `DATABASE_PUBLIC_URL="${{Postgres.DATABASE_URL}}"`  ← same as DATABASE_URL (internal)

**Correct:**

- `DATABASE_URL="${{Postgres.DATABASE_URL}}"`  (internal, for app runtime)
- `DATABASE_PUBLIC_URL="${{Postgres.DATABASE_PUBLIC_URL}}"`  (if your Postgres service exposes a public URL variable)

If Railway does not expose a variable like `Postgres.DATABASE_PUBLIC_URL`, copy the **public** connection string from the Postgres service’s “Connect” / “Public” tab and set **DATABASE_PUBLIC_URL** to that value in the web service variables.

4. Redeploy. The pre-deploy command in `railway.toml` runs:

   ```bash
   DATABASE_URL="${DATABASE_PUBLIC_URL}" bundle exec rails db:migrate
   ```

   So migrations will use the public URL and can reach Postgres from the deploy environment.

## Summary

| Variable             | Used by              | Should be                    |
|----------------------|----------------------|-----------------------------|
| **DATABASE_URL**     | Rails at runtime     | Internal URL (private IP)   |
| **DATABASE_PUBLIC_URL** | Pre-deploy `db:migrate` | **Public** URL (e.g. `*.proxy.rlwy.net`) |

Once **DATABASE_PUBLIC_URL** points to the public Postgres URL, `db:migrate` in pre-deploy should succeed.
