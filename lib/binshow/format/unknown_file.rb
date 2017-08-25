require 'binshow/type_funcs'

module Binshow
  module Format
    module UnknownFile
      def self.node_generate_attrs(node, file)
        errors = {}
        TypeFuncs.each do |type, type_funcs|
          next if !type_funcs.respond_to?(:node_determine_type)
          node_attrs, error = type_funcs.node_determine_type(node, file)
          if node_attrs
            return node_attrs
          else
            errors[type] = error
          end
        end
        raise "Could not determine the type: #{errors.inspect}"
      end
    end
  end
end
