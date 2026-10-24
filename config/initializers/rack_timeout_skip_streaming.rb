# rack-timeout 0.7.0 has no per-path skip hook, and the admin chat
# streaming endpoint can run for 30-60 seconds across a multi-tool
# agent loop. Letting the middleware's default 15-second budget apply
# would raise Rack::Timeout::RequestTimeoutException mid-stream and
# close the browser's EventSource mid-sentence.
#
# Module#prepend on Rack::Timeout#call lets us short-circuit the
# middleware for the chat path only — every other request keeps the
# normal 15-second budget.
if defined?(Rack::Timeout)
  module RackTimeoutSkipStreaming
    SKIP_PATHS = %w[/admin/chat/messages].freeze

    def call(env)
      return @app.call(env) if SKIP_PATHS.include?(env['PATH_INFO'])
      super
    end
  end
  Rack::Timeout.prepend(RackTimeoutSkipStreaming)
end
