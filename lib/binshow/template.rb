module Binshow
  TemplateU32 = {
    length: 4,
    type: :u32,
    value: -> (d) { d.unpack('L<')[0] || raise },
  }.freeze

  TemplateU16 = {
    length: 2,
    type: :u16,
    value: -> (d) { d.unpack('s<')[0] || raise },
  }.freeze

  def self.prepare_template(template)
    # We want our templates to be hashes we can store the total length,
    # which is needed when calling File#read.
    template = { children: template } if template.is_a?(Array)

    prepare_template_core(template, 0)
  end

  # Adds offsets and lengths recursively to every hash in the template.
  def self.prepare_template_core(template, offset)
    orig_template = template
    template = template.dup
    template[:offset] = offset

    if template[:children]
      total_length = 0
      prepared_children = template[:children].map do |child|
        prepared_child = prepare_template_core(child, offset + total_length)
        total_length += prepared_child.fetch(:length)
        prepared_child
      end
      template[:children] = prepared_children

      if template[:length] && template[:length] != total_length
        raise "Template length mismatch: " +
              "#{template[:length]} != #{total_length} " +
              "for #{orig_template.inspect}."
      end
      template[:length] = total_length
    end

    if !template[:length]
      raise "Could not determine length for #{orig_template.inspect}."
    end

    template
  end

  def self.fill_in_template(template, offset, file)
    file.seek(offset)
    data = file.read(template.fetch(:length))
    fill_in_template_core(template, offset, data)
  end

  def self.fill_in_template_core(template, offset, data)
    template = template.dup
    template.each do |k, v|
      if v.is_a?(Proc)
        fragment = data[template.fetch(:offset), template.fetch(:length)]
        template[k] = v.call(fragment)
        raise "Got nil for input #{fragment.inspect} to #{template.inspect}" if template[k].nil?
      end
    end

    if template[:children]
      filled_children = template[:children].map do |child|
        fill_in_template_core(child, offset, data)
      end
      template[:children] = filled_children
    end

    template[:offset] += offset

    template
  end
end

