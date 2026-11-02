require_relative 'boot'

# The anthropic gem (official 1.x SDK) re-opens nested modules like
# `Anthropic::Beta` from many files; once Rails 6's Zeitwerk is loaded
# below, its const_missing hook raises on those lookups mid-boot and
# the gem fails to load. Requiring the gem FIRST — before `rails/all`
# wires Zeitwerk up — lets Ruby define the whole module tree with
# plain Ruby semantics. The gem is pinned `require: false` in the
# Gemfile so Bundler.require below doesn't re-trigger loading.
require 'anthropic'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ActionPlan
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # App-wide default timezone. Interim fix — should eventually be
    # per-user (see users table + preference selector). Alaska since
    # that's where the fires are being managed from right now.
    config.time_zone = 'Alaska'

    # Rails only loads config/locales/*.yml by default; translations here
    # are organized in subfolders (views/admin, views/navigation, models).
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
