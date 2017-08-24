require 'binshow/little_endian_data_reader'

module Binshow
  module Format
    # Portable Executable - Windows .exe or .dll file
    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms680547.aspx
    module Pe
      using LittleEndianDataReader

      module File
        SIGNATURE_OFFSET_OFFSET = 0x3c
        SIGNATURE_LENGTH = 4
        SIGNATURE = "PE\0\0".freeze
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

          return [:pe_file]
        end

        def self.node_generate_attrs(node, file)
          node_offset = node.fetch(:offset)
          node_length = node.fetch(:length)
          file.seek(node_offset + SIGNATURE_OFFSET_OFFSET)
          signature_offset = file.read_u32
          header_offset = signature_offset + SIGNATURE_LENGTH
          file.seek(node_offset + header_offset)
          header_bytes = file.read(COFF_HEADER_LENGTH)
          header_data = header_bytes.unpack('S<S<L<L<L<S<S<')

          attrs = {}

          machine_type_code = header_data[0]
          attrs[:machine_type] = MACHINE_TYPES.fetch(machine_type_code, :invalid)

          characteristics_bitmap = header_data[6]
          # TODO: decode the meaning of the bitmap instead of just storing
          # a hex string
          attrs[:chars_as_hex_string] = "%04x" % characteristics_bitmap

          attrs
        end

        def self.node_generate_children(node, file)
          # TODO
          []
        end
      end
    end
  end
end
