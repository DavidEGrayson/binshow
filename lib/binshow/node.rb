require 'binshow/type_funcs'

module Binshow
  def self.node_get_type(node, file)
    if node[:lazy_type]
      node.merge! node_determine_type(node, file)
      node.delete :lazy_type
    end
    node.fetch(:type)
  end

  def self.node_type_funcs(node, file)
    TypeFuncs.fetch(node_get_type(node, file))
  end

  def self.node_get_attrs(node, file)
    if node[:lazy_attrs]
      node.merge! node_type_funcs(node, file).node_generate_attrs(node, file)
      node.delete :lazy_attrs
    end
    node
  end

  def self.node_get_children(node, file)
    if node[:lazy_children]
      node[:children] = node_type_funcs(node, file).node_generate_children(node, file)
      node.delete :lazy_children
    end
    node.fetch(:children, [])
  end

  def self.node_forget_children(node)
    node.delete(:children)
  end

  def self.node_determine_type(node, file)
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
