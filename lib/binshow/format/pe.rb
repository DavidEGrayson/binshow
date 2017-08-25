require 'binshow/little_endian_data_reader'
require 'binshow/make_node'

module Binshow
  module Format
    # Portable Executable - Windows .exe or .dll file
    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms680547.aspx
    module Pe
      using LittleEndianDataReader

      module File
        SIGNATURE_OFFSET_OFFSET = 0x3c
        SIGNATURE_LENGTH = 4
        SIGNATURE = "PE\0\0".force_encoding('BINARY').freeze
        COFF_HEADER_LENGTH = 20
        MACHINE_TYPES = {
          0 => :unknown,
          0x14c => :i386,
          0x8664 => :amd64,
        }

        def self.node_determine_type(node, file)
          node_offset = node.fetch(:offset)
          node_length = node.fetch(:length)
          if node_length < SIGNATURE_OFFSET_OFFSET + 4
            return [nil, "The file is too short."]
          end
          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32
          if node_length < signature_offset + SIGNATURE_LENGTH + COFF_HEADER_LENGTH
            return [nil, "The file is too short to hold the signature and COFF header."]
          end
          file.seek(node_offset + signature_offset)
          signature = file.read(SIGNATURE_LENGTH)
          if signature != SIGNATURE
            return [nil, "Incorrect PE signature at offset #{signature_offset}."]
          end

          # Note: For efficiency, it would be nice to record the PE signature
          # location here, but we don't really have a safe place to put it.

          return { type: :pe_file, lazy_children: true }
        end

        def self.get_header(node, file)
          node_offset = node.fetch(:offset)
          node_length = node.fetch(:length)
          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32
          header_offset = signature_offset + SIGNATURE_LENGTH
          file.seek(node_offset + header_offset)
          header_bytes = file.read(COFF_HEADER_LENGTH)
          header_data = header_bytes.unpack('S<S<L<L<L<S<S<')
          [header_data, header_offset]
        end

        def self.node_generate_children(node, file)
          node_offset = node.fetch(:offset)
          node_length = node.fetch(:length)

          header_data, header_offset = get_header(node, file)

          children = []

          children << Binshow.make_magic(header_offset - 4, SIGNATURE)

          offset = node_offset + header_offset
          coff_header_members = Binshow.make_struct_nodes offset, file, [
            [:machine_type, :u16],
            [:number_of_sections, :u16],
            [:time_date_stamp, :u32],
            [:pointer_to_symbol_table, :u32],
            [:number_of_symbols, :u32],
            [:size_of_optional_header, :u16],
            [:characteristics, :u16],
          ]

          mt = coff_header_members[0]
          code = mt.fetch(:value)
          mt[:type] = :coff_machine_type
          mt[:value] = MACHINE_TYPES.fetch(code, code)

          coff_header = {
            offset: offset,
            length: COFF_HEADER_LENGTH,
            type: :coff_header,
            children: coff_header_members
          }

          children << coff_header

          # TODO: other children

          children
        end
      end
    end
  end
end
