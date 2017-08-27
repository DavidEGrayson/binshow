module Binshow
  module LittleEndianDataReader  # TODO: maybe just use FieldTypes instead of this
    refine IO do
      def read_u8
        read(1).ord
      end

      def read_i8
        read(1).unpack('c')[0]
      end

      def read_i16
        read(2).unpack('s<')[0]
      end

      def read_u16
        read(2).unpack('S<')[0]
      end

      def read_i32
        read(4).unpack('l<')[0]
      end

      def read_u32
        read(4).unpack('L<')[0]
      end

      def read_utf8_string
        str = ""
        while true
          chunk = read(1024)
          if !chunk
            raise "Null termination not found while reading UTF-8 string."
          end
          end_index = chunk.index("\0")
          if end_index
            end_index += str.size
            str << chunk
            return str[0, end_index].force_encoding("UTF-8")
          else
            str << chunk
          end
        end
      end
    end
  end
end
