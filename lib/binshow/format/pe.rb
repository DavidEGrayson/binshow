require 'binshow/little_endian_data_reader'
require 'binshow/make_node'
require 'binshow/template'

module Binshow
  module Format
    # Portable Executable - Windows .exe or .dll file
    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms680547.aspx
    module Pe
      SIGNATURE_OFFSET_OFFSET = 0x3c
      SIGNATURE_LENGTH = 4
      SIGNATURE = "PE\0\0".force_encoding('BINARY').freeze
      COFF_HEADER_LENGTH = 20
      MACHINE_TYPES = {
        0 => :unknown,
        0x14c => :i386,
        0x8664 => :amd64,
      }
      SECTION_HEADER_LENGTH = 40

      CoffHeaderTemplate = Binshow.prepare_template \
        length: COFF_HEADER_LENGTH,
        type: :coff_header,
        children: [
          TemplateU16.merge(name: :machine_type),
          TemplateU16.merge(name: :number_of_sections),
          TemplateU32.merge(name: :time_date_stamp),
          TemplateU32.merge(name: :pointer_to_symbol_table),
          TemplateU32.merge(name: :number_of_symbols),
          TemplateU16.merge(name: :size_of_optional_header),
          TemplateU16.merge(name: :characteristics),
        ]

      using LittleEndianDataReader

      module File
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
            type: :dos_stub,
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

        def self.make_optional_header(offset, length, file)
          {
            offset: offset,
            length: length,
            type: :pe_optional_header,
            # TODO: fully decode the optional headers
          }
        end

        def self.make_section_table(offset, section_count, file)
          # TODO: new kind of lazy children for cases where there are O(N) children
          {
            offset: offset,
            length: section_count * SECTION_HEADER_LENGTH,
            type: :pe_section_table,
            lazy_children: true,
          }
        end

        def self.make_coff_header(offset, file)
          coff_header = Binshow.fill_in_template(CoffHeaderTemplate, offset, file)

          mt = coff_header.fetch(:children)[0]
          code = mt.fetch(:value)
          mt[:type] = :coff_machine_type
          mt[:value] = MACHINE_TYPES.fetch(code, code)

          coff_header
        end

        def self.node_generate_children(node, file)
          node_offset = node.fetch(:offset)

          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32
          header_offset = node_offset + signature_offset + SIGNATURE_LENGTH

          children = []
          children << make_dos_stub(node_offset, signature_offset)
          children << Binshow.make_magic(node_offset + signature_offset, SIGNATURE)
          children << coff_header = make_coff_header(header_offset, file)

          optional_offset = header_offset + coff_header.fetch(:length)
          optional_length = coff_header[:children][5].fetch(:value)
          children << make_optional_header(optional_offset, optional_length, file)

          section_count = coff_header[:children][1].fetch(:value)
          section_table_offset = optional_offset + optional_length

          children << section_table =
            make_section_table(section_table_offset, section_count, file)

          # TODO: other children

          children
        end
      end

      module SectionTable
        def self.node_each_child(node, file)
          offset = 0
          while offset < node.fetch(:length)
            header = {
              offset: node.fetch(:offset) + offset,
              length: SECTION_HEADER_LENGTH,
              type: :pe_section_header,
              lazy_children: true,
            }
            yield header
            offset += SECTION_HEADER_LENGTH
          end
        end
      end

      module SectionHeader
        Template = Binshow.prepare_template [
          {
            length: 8,
            type: :str_utf8_zero_padded,
            name: :name,
            value: -> (d) { d.force_encoding('UTF-8').gsub(/\0+\Z/, '') }
          },
          TemplateU32.merge(name: :virtual_size),
          TemplateU32.merge(name: :virtual_address),
          TemplateU32.merge(name: :size_of_raw_data),
          TemplateU32.merge(name: :pointer_to_raw_data),
          TemplateU32.merge(name: :pointer_to_relocations),
          TemplateU32.merge(name: :pointer_to_line_numbers),
          TemplateU16.merge(name: :number_of_relocations),
          TemplateU16.merge(name: :number_of_line_numbers),
          TemplateU32.merge(name: :characteristics),
        ]

        def self.node_generate_children(node, file)
          fake_node = Binshow.fill_in_template(Template, node.fetch(:offset), file)
          fake_node.fetch(:children)
        end
      end
    end
  end
end
