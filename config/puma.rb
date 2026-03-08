# frozen_string_literal: true

# Lower default threads in staging/production for small replicas (e.g. 512 MB)
default_threads = ["production", "staging"].include?(ENV["RAILS_ENV"]) ? 3 : 5
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { default_threads }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Use ENV PORT (Railway, Heroku, etc.) and bind to all interfaces
app_port = ENV.fetch("PORT", 3000)
bind "tcp://0.0.0.0:#{app_port}"

environment ENV.fetch("RAILS_ENV", "development")

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

plugin :tmp_restart
