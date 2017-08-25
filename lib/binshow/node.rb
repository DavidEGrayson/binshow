require 'binshow/type_funcs'

module Binshow
  def self.node_type_funcs(node, file)
    TypeFuncs.fetch(node.fetch(:type))
  end

  def self.node_get_attrs(node, file)
    while node[:lazy_attrs]
      node.delete :lazy_attrs
      node.merge! node_type_funcs(node, file).node_generate_attrs(node, file)
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
end
