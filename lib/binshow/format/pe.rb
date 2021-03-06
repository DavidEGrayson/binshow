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
      COFF_SYMBOL_LENGTH = 18

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

        def self.make_coff_header(offset, file)
          coff_header = Binshow.fill_in_template(CoffHeaderTemplate, offset, file)

          mt = coff_header.fetch(:children)[0]
          code = mt.fetch(:value)
          mt[:type] = :coff_machine_type
          mt[:value] = MACHINE_TYPES.fetch(code, code)

          coff_header
        end

        def self.make_optional_header(offset, length, file)
          {
            offset: offset,
            length: length,
            type: :pe_optional_header,
            # TODO: fully decode the optional headers
          }
        end

        def self.make_section_table(offset, section_count, string_table, file)
          {
            offset: offset,
            length: section_count * SECTION_HEADER_LENGTH,
            type: :pe_section_table,
            lazy_children: true,
            cross_ref: {
              string_table_offset: string_table.fetch(:offset),
              string_table_length: string_table.fetch(:length),
            }
          }
        end

        def self.make_string_table(offset, file)
          file.seek(offset)
          length = file.read_u32
          #strings = file.read(length - 4)
          #raise if strings.size != length - 4

          {
            offset: offset,
            length: length,
            type: :pe_string_table,
            # value: strings,
          }
        end

        def self.node_generate_children(node, file)
          node_offset = node.fetch(:offset)

          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32
          header_offset = node_offset + signature_offset + SIGNATURE_LENGTH

          dos_stub = make_dos_stub(node_offset, signature_offset)
          magic = Binshow.make_magic(node_offset + signature_offset, SIGNATURE)
          coff_header = make_coff_header(header_offset, file)

          hv = -> (n) { Binshow.find_child(coff_header, file, n).fetch(:value) }

          symbol_table_offset = hv.(:pointer_to_symbol_table)
          symbol_count = hv.(:number_of_symbols)

          if symbol_table_offset != 0
            string_table_offset = symbol_table_offset + symbol_count * COFF_SYMBOL_LENGTH

            symbol_table = nil # tmphax
            # TODO: symbol_table = make_symbol_table(symbol_table_offset, symbol_count, file)

            string_table = make_string_table(string_table_offset, file)
          end

          optional_offset = header_offset + coff_header.fetch(:length)
          optional_length = hv.(:size_of_optional_header)
          optional_header = make_optional_header(optional_offset, optional_length, file)

          section_table_offset = optional_offset + optional_length
          section_count = hv.(:number_of_sections)

          section_table = make_section_table(
            section_table_offset, section_count, string_table, file)

          # TODO: other children

          [dos_stub, magic, coff_header, optional_header,
           section_table, symbol_table, string_table].compact
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
              cross_ref: node.fetch(:cross_ref)
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

          string_table_offset = node.fetch(:cross_ref).fetch(:string_table_offset)

          # Look up the name in the string table if needed.
          name_node = Binshow.find_child(fake_node, file, :name)
          raw_name = name_node.fetch(:value)
          if raw_name[0] == "/"
            offset = raw_name[1,7].to_i
            file.seek(string_table_offset + offset)
            real_name = file.read_utf8_string()
            name_node[:real_name] = real_name
          else
            name_node[:real_name] = raw_name
          end

          fake_node.fetch(:children)
        end
      end
    end
  end
end
