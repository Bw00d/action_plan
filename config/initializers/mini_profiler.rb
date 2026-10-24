# Rack::MiniProfiler wraps every response (including SSE) to inject its
# badge, which buffers the whole body and defeats streaming. Skip the
# admin chat endpoint so tokens flow through as they're generated.
if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.skip_paths ||= []
  Rack::MiniProfiler.config.skip_paths << '/admin/chat/messages'
end
