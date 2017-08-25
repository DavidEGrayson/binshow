module Binshow
  FieldTypes = {
    i8: [1, 'c'],
    u8: [1, 'C'],
    i16: [2, 's<'],
    u16: [2, 'S<'],
    i32: [4, 'l<'],
    u32: [4, 'L<'],
  }

  def self.make_struct_nodes(offset, file, fields)
    field_types = fields.map { |f| f[1] }
    lengths = field_types.map { |t| FieldTypes.fetch(t)[0] }
    struct_length = lengths.inject(:+)

    file.seek(offset)
    binary_data = file.read(struct_length)
    if binary_data.length != struct_length
      raise "Wrong amount of struct data read at offset #{offset}: " +
            "expected #{struct_length}, got #{binary_data.length}"
    end

    stream = StringIO.new(binary_data)
    field_offset = offset
    fields.map do |name, type|
      length, unpack_code = FieldTypes.fetch(type)
      value = stream.read(length).unpack(unpack_code)[0]

      node = {
        offset: field_offset,
        length: length,
        type: type,
        name: name,
        value: value,
      }

      field_offset += length

      node
    end
  end

  def self.make_magic(offset, str)
    str = str.dup.freeze if !str.frozen?
    {
      offset: offset,
      length: str.bytesize,
      type: :magic,
      value: str,
      children: [],
    }
  end

end
