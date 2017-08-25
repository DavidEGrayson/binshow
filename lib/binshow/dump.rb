require 'binshow/node'

module Binshow
  DumpIndentation = '  '

  def self.dump_entire_file(file, output = $stdout, indent = '')
    root = { offset: 0, length: file.size, lazy_type: true }
    dump_node(root, file, output, indent)
  end

  def self.dump_node(node, file, output, indent)
    node_get_type(node, file)
    node_get_attrs(node, file)
    dump_node_attrs(node, output, indent)

    children = node_get_children(node, file)
    children.each do |child|
      dump_node(child, file, output, indent + DumpIndentation)
    end

    # For better garbage collection.
    node_forget_children(node)
  end

  def self.dump_node_attrs(node, output, indent)
    line = indent.dup
    line << "#{node[:name]} " if node[:name]
    line << "#{node.fetch(:type)} "
    line << "(#{node.fetch(:offset)},+#{node.fetch(:length)})"
    output.puts line
    indent += DumpIndentation
    node.each do |k, v|
      case
      when %i(offset length name type lazy_children children).include?(k)
        next
      when v.is_a?(String) #&& !v.ascii_only?
        v = v.inspect
      end
      output.puts indent + "#{k}: #{v}"
    end
  end
end
