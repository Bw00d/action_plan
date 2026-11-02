release: bundle exec rails db:migrate && bundle exec rails positions:load
web: bundle exec puma -C config/puma.rb
worker: bundle exec good_job start
