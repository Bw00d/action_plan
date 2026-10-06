# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port        ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Clustered mode — forks N worker processes so the app can handle
# multiple requests in parallel on real CPU cores. WEB_CONCURRENCY is
# set in Heroku config; defaults to 2 for Standard-1X / 3 for
# Standard-2X. Combined with 5 threads each, that's ~10–15 concurrent
# in-flight requests before any queue — plenty for ~24 concurrent
# users of this app.
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# preload_app! lets the N workers share the already-loaded application
# via copy-on-write, so memory per extra worker is a fraction of a
# fresh boot. Required for the on_worker_boot DB reconnection below.
preload_app!

# After the master forks a worker, re-establish its ActiveRecord
# connection — without this, forked workers inherit the master's
# connection and fight over it.
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart
