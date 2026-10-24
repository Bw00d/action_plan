# best_in_place 3.1.1 is unmaintained in the 3.x line and relies on
# Ruby 2.x's implicit kwargs→positional-hash coercion. Under Ruby 3.2+,
# `Renderer.new(method:, type:, attr:, helper_options:)` raises
# "unknown keywords" because Struct.new(:opts) is strict about args.
# Wrapping each call site in `{ ... }` restores the positional hash.
#
# Can be dropped if we ever move to best_in_place 4.x (needs Rails 7).
require 'best_in_place/display_methods'

module BestInPlace
  module DisplayMethods
    class << self
      def add_model_method(klass, attr, display_as)
        model_attributes(klass)[attr.to_s] =
          Renderer.new({ method: display_as.to_sym, type: :model })
      end

      def add_helper_method(klass, attr, helper_method, helper_options = nil)
        model_attributes(klass)[attr.to_s] =
          Renderer.new({ method:         helper_method.to_sym,
                         type:           :helper,
                         attr:           attr,
                         helper_options: helper_options })
      end

      def add_helper_proc(klass, attr, helper_proc)
        model_attributes(klass)[attr.to_s] =
          Renderer.new({ type: :proc, attr: attr, proc: helper_proc })
      end
    end
  end
end
