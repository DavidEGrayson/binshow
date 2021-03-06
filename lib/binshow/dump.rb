require 'binshow/node'

module Binshow
  DumpIndentation = '  '

  def self.dump_entire_file(file, output = $stdout, indent = '')
    root = { offset: 0, length: file.size, type: :unknown_file, lazy_attrs: true }
    dump_node(root, file, output, indent)
  end

  def self.dump_node(node, file, output, indent)
    node_get_attrs(node, file)
    dump_node_attrs(node, output, indent)

    node_each_child(node, file) do |child|
      dump_node(child, file, output, indent + DumpIndentation)
    end
  end

  def self.dump_node_attrs(node, output, indent)
    line = indent.dup
    if node[:name]
      line << "#{node[:name]} "
    else
      line << "#{node.fetch(:type)} "
    end
    line << "(#{node.fetch(:offset)},+#{node.fetch(:length)})"
    if node[:value]
      line << ": #{dump_printable(node.fetch(:value))}"
    end
    output.puts line
    indent += DumpIndentation
    node.each do |k, v|
      if %i(offset length name type lazy_children children value cross_ref).include?(k)
        next
      end
      output.puts indent + "#{k}: #{dump_printable(v)}"
    end
  end

  def self.dump_printable(value)
    if value.is_a?(String)
      return value.inspect
    end
    value
  end
end
