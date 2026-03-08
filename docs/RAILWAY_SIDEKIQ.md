# Running Sidekiq on Railway

Your Rails app uses **Sidekiq** for background jobs (e.g. `BookingNotificationJob`). On Railway you need **two processes**:

---

## ⚠️ "Name does not resolve (Redis.railway.internal)" — Quick fix

If the **worker** logs show:

```text
getaddrinfo: Name does not resolve (redis://Redis.railway.internal:6379)
```

the worker can’t reach Redis via the internal hostname. **Fix:** on the **worker** service, set the **public** Redis URL.

The app prefers **REDIS_PUBLIC_URL** for Sidekiq when it is set. So either:

- **Option A (recommended):** In the **worker** service → **Variables**, add **REDIS_PUBLIC_URL** = `${{Redis.REDIS_PUBLIC_URL}}` (or paste the public URL from your Redis service). Leave REDIS_URL as-is. Sidekiq will use REDIS_PUBLIC_URL.
- **Option B:** In the **worker** service → **Variables**, set **REDIS_URL** to the public URL (e.g. `${{Redis.REDIS_PUBLIC_URL}}`) so it overrides the internal one.

Then **redeploy** the worker. The web service can keep using the internal REDIS_URL.

1. **Web** – Puma (already running via your Dockerfile `CMD`).
2. **Worker** – Sidekiq (separate service, same codebase).

Both use the same **Redis** and **Postgres** (DATABASE_URL). This follows the [Railway Rails guide – Set up Workers & Cron Jobs with Sidekiq](https://docs.railway.com/guides/rails#set-up-workers--cron-jobs-with-sidekiq).

---

## How to start Sidekiq on Railway (two options)

- **Option A – Separate Dockerfile (recommended)**  
  Create a **Worker** service, set variable `RAILWAY_DOCKERFILE_PATH` = `Dockerfile.sidekiq` (or `backend/Dockerfile.sidekiq` if root is repo root). Leave **Custom Start Command** empty; the image `CMD` is already `bundle exec sidekiq`.

- **Option B – Same image, custom start**  
  Create a **Worker** service using the same build as web. In **Settings → Deploy** set **Custom Start Command** to:
  ```bash
  bundle exec sidekiq
  ```

In both cases the worker needs **REDIS_URL**, **DATABASE_URL**, **RAILS_ENV**, **SECRET_KEY_BASE**, and any other app env vars (see §2 below).

---

## 1. Redis and env (you already have this)

- Redis plugin is added; **REDIS_URL** is set (use the **internal** URL for services in the same project, e.g. `redis://...@Redis.railway.internal:6379`).
- Your app already uses `REDIS_URL` for Sidekiq and only enables Sidekiq when `REDIS_URL` is set.

---

## 2. Add a Sidekiq worker service on Railway

1. In your Railway project, click **+ New** → **Empty Service** (or duplicate your existing backend service).
2. Name it e.g. **ollazen-backend-worker** (or **booking-platform-worker**).
3. **Connect the same repo** (and same **root directory** if monorepo, e.g. `backend`).
4. **Build** (when Build is locked by `railway.toml`):  
   You can’t change **Settings → Build** because it’s set in `railway.toml`. Override the Dockerfile **per service** with a variable:
   - Open the **worker** service → **Variables**.
   - Add a **new variable**:
     - **Name:** `RAILWAY_DOCKERFILE_PATH`
     - **Value:** `Dockerfile.sidekiq` if the service **Root Directory** is `backend`, or `backend/Dockerfile.sidekiq` if the service builds from repo root.
   - This makes the worker build with `Dockerfile.sidekiq` (see [Railway: Custom Dockerfile Path](https://docs.railway.com/guides/dockerfiles#custom-dockerfile-path)). The image `CMD` is already `bundle exec sidekiq`, so you don’t need a Custom Start Command.
   - **Alternative (no variable):** Leave the worker using the same build as web (from `railway.toml`). In **Settings → Deploy** set **Custom Start Command** to `bundle exec sidekiq` so the same image runs Sidekiq instead of Puma.
5. **Deploy / Start command**:
   - If you set **RAILWAY_DOCKERFILE_PATH** on the worker: leave **Custom Start Command** empty (the Sidekiq image already runs `bundle exec sidekiq`).
   - If you did **not** set RAILWAY_DOCKERFILE_PATH: set **Custom Start Command** to `bundle exec sidekiq`.
   - Leave **Custom Start Command** empty on your **web** service.
6. **Variables**: The worker needs the same env as the web service so it can talk to DB and Redis:
   - **REDIS_URL** – Use the **public** Redis URL on the worker (e.g. `${{Redis.REDIS_PUBLIC_URL}}`). The internal URL (`Redis.railway.internal`) often fails to resolve in the worker container; see **§4 Troubleshooting** if you see `Name does not resolve`.
   - **DATABASE_URL** (or **DATABASE_PUBLIC_URL** if you use it for migrations).
   - **RAILS_ENV** (e.g. `staging` or `production`).
   - **SECRET_KEY_BASE**.
   - Any other vars your app needs (JWT secrets, Cloudinary, etc.).

   Easiest: in Railway, use **Variable references** or copy the same variables from the web service. Do **not** give the worker a **PORT**-based health check; Sidekiq doesn’t serve HTTP.

7. **Optional**: Turn off **preDeployCommand** (migrations) for the worker so only the web service runs `rails db:migrate`. In the worker service Settings → Deploy, clear the pre-deploy command or set it to `echo "skip migrations"`.

8. Deploy the worker service (same branch as web). After deploy, the web service enqueues jobs to Redis and the worker service runs `bundle exec sidekiq` and processes them.

---

## 3. Summary

| Service              | Dockerfile           | Start command              | Role                          |
|----------------------|----------------------|----------------------------|-------------------------------|
| ollazen-backend (web)   | `Dockerfile`         | (default: Puma)            | Serves HTTP, enqueues jobs    |
| ollazen-backend-worker  | `Dockerfile.sidekiq` | (default: Sidekiq)         | Runs Sidekiq, processes jobs  |

Both use the same **REDIS_URL** (internal) and **DATABASE_URL**. Jobs enqueued by the web process will be picked up by the worker process.

---

## 4. Troubleshooting: "Name does not resolve (Redis.railway.internal)"

If the worker fails with:

```text
getaddrinfo: Name does not resolve (redis://Redis.railway.internal:6379)
```

the worker container cannot resolve Railway’s internal Redis hostname. Fix it by using the **public** Redis URL for the worker:

1. In the **worker** service only, set **REDIS_URL** to the **same value as REDIS_PUBLIC_URL** (from your Redis plugin / Variables).
   - Example: `redis://default:YOUR_PASSWORD@centerbeam.proxy.rlwy.net:31916` (your host will differ).
2. Redeploy the worker.

The web service can keep using the internal **REDIS_URL** (`Redis.railway.internal`). Only the worker needs the public URL when internal DNS doesn’t resolve. Both will still use the same Redis instance.

---

## 5. Verify

- After deploy, trigger an action that enqueues a job (e.g. create a booking).
- In Railway, open the **worker** service → **Logs**. You should see Sidekiq start and then process the job (e.g. `BookingNotificationJob`).
- If jobs stay in the queue, check that the worker service has **REDIS_URL** set (use **REDIS_PUBLIC_URL** on the worker if you hit the "Name does not resolve" error).
