# Rails 6.0's ActiveRecord::Relation#_exec_scope is not marked
# `ruby2_keywords`, so on Ruby 3+ the kwargs flag Rails attaches to
# scope args at named.rb:203 gets dropped before reaching `instance_exec`,
# and a scope defined as a kwargs-only lambda (e.g.
# `scope :foo, ->(column: :default) { ... }`) is then invoked with a
# plain positional hash and raises
# `ArgumentError: wrong number of arguments (given 1, expected 0)`.
#
# GoodJob 3.99.x advisory_lockable scopes are the proximate victim here:
# the worker's heartbeat calls `GoodJob::Process.inactive`, whose scope
# body calls `joins_advisory_locks(column: ...)`, which blows up on
# every heartbeat and crash-loops the worker dyno.
#
# Rails 6.1 fixes this by adding `ruby2_keywords(:_exec_scope)` right
# below the method definition. We backport that one line.
if defined?(ActiveRecord::Relation) &&
   Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 0 &&
   ActiveRecord::Relation.respond_to?(:ruby2_keywords, true)
  ActiveRecord::Relation.send(:ruby2_keywords, :_exec_scope)
end
