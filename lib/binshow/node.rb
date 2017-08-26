require 'binshow/type_funcs'

module Binshow
  def self.node_type_funcs(node)
    TypeFuncs.fetch(node.fetch(:type))
  end

  def self.node_get_attrs(node, file)
    while node[:lazy_attrs]
      node.delete :lazy_attrs
      node.merge! node_type_funcs(node).node_generate_attrs(node, file)
    end
    node
  end

  def self.node_each_child(node, file, &proc)
    if node[:children]
      return node[:children].each(&proc)
    end

    if node[:lazy_children]
      funcs = node_type_funcs(node)

      if funcs.respond_to?(:node_generate_children)
        node[:children] = funcs.node_generate_children(node, file)
        node.delete :lazy_children
        return node[:children].each(&proc)
      else
        return funcs.node_each_child(node, file, &proc)
      end
    end
  end

  def self.fetch_child_value(node, file, child_name)
    node_each_child(node, file) do |child|
      if child[:name] == child_name
        return child.fetch(:value)
      end
    end
    nil
  end
end
