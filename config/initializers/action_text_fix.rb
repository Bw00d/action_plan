# Fix for ActionText autoloading deprecation warning in Rails 6
# ActionText tries to autoload constants during initialization
# We need to eager load them to avoid the deprecation warning
Rails.application.config.after_initialize do
  ActionText::ContentHelper if defined?(ActionText)
  ActionText::TagHelper if defined?(ActionText)
end