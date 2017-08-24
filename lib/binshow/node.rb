require 'binshow/type_funcs'

module Binshow
  def self.node_get_type(node, file)
    node.fetch(:type) do
      node[:type] = node_determine_type(node, file)
    end
  end

  def self.node_type_funcs(node, file)
    TypeFuncs.fetch(node_get_type(node, file))
  end

  def self.node_get_attrs(node, file)
    node.fetch(:attrs) do
      node[:attrs] = node_type_funcs(node, file).node_generate_attrs(node, file)
    end
  end

  def self.node_get_children(node, file)
    node.fetch(:children) do
      node[:children] = node_type_funcs(node, file).node_generate_children(node, file)
    end
  end

  def self.node_forget_children(node)
    node.delete(:children)
  end

  def self.node_determine_type(node, file)
    errors = {}
    TypeFuncs.each do |type, type_funcs|
      next if !type_funcs.respond_to?(:node_determine_type)

      node_type, error = type_funcs.node_determine_type(node, file)
      if node_type
        node[:type] = node_type
        return node[:type]
      else
        errors[type] = error
      end
    end
    raise "Could not determine the type: #{errors.inspect}"
  end
end
