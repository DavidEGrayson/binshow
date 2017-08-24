module Binshow
  module LittleEndianDataReader
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

      def read_long
        read(8).unpack('q<')[0]
      end
    end
  end
end
