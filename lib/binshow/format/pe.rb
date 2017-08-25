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

        def self.make_dos_stub(node_offset, signature_offset)
          {
            offset: node_offset,
            length: signature_offset,
            type: :dos_program,
            children: [
              {
                offset: node_offset + 0x3c,
                length: 4,
                type: :u32,
                name: :signature_offset,
                value: signature_offset,
              }
            ]
          }
        end

        def self.make_coff_header(offset, file)
          coff_header_members, length = Binshow.make_struct_nodes offset, file, [
            [:machine_type, :u16],
            [:number_of_sections, :u16],
            [:time_date_stamp, :u32],
            [:pointer_to_symbol_table, :u32],
            [:number_of_symbols, :u32],
            [:size_of_optional_header, :u16],
            [:characteristics, :u16],
          ]

          raise if length != COFF_HEADER_LENGTH

          mt = coff_header_members[0]
          code = mt.fetch(:value)
          mt[:type] = :coff_machine_type
          mt[:value] = MACHINE_TYPES.fetch(code, code)

          {
            offset: offset,
            length: length,
            type: :coff_header,
            children: coff_header_members
          }
        end

        def self.node_generate_children(node, file)
          node_offset = node.fetch(:offset)

          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32

          children = []
          children << make_dos_stub(node_offset, signature_offset)
          children << Binshow.make_magic(signature_offset, SIGNATURE)
          header_offset = node_offset + signature_offset + SIGNATURE_LENGTH
          children << coff_header = make_coff_header(header_offset, file)

          # TODO: other children

          children
        end
      end
    end
  end
end
