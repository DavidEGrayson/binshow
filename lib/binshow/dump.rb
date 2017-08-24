require 'binshow/node'

module Binshow
  DumpIndentation = '  '

  def self.dump_entire_file(file, output = $stdout, indent = '')
    root = { offset: 0, length: file.size }
    dump_node(root, file, output, indent)
  end

  def self.dump_node(node, file, output, indent)
    node_get_attrs(node, file)
    dump_node_attrs(node, file, output, indent)

    children = node_get_children(node, file)
    children.each do |child|
      dump_node(child, file, output, indent + DumpIndentation)
    end

    # For better garbage collection.
    node_forget_children(node)
  end
end