module BRS::Write
  extend self

  class WriteException < Exception
  end

  def write_string(io : IO, string : String)
    io.write_bytes(string.size + 1, IO::ByteFormat::LittleEndian)
    io << string
    io.write(Bytes.new(1, 0_u8))
  end

  def write_uuid(io : IO, uuid : UUID)
    uuid.bytes.to_a.in_groups_of(4).map(&.reverse).each &.each { |byte| io.write_byte(byte.not_nil!) }
  end

  def write_time(io : IO, time : Time)
    span = time - Time.utc(seconds: 0, nanoseconds: 0)
    io.write_bytes(span.total_microseconds.to_i64 * 10_i64, IO::ByteFormat::LittleEndian)
  end

  def write_array(io : IO, array : Array(T), &block : T ->) forall T
    io.write_bytes(array.size, IO::ByteFormat::LittleEndian)
    array.each &block
  end

  def write_compressed(io : IO, &block : IO::Memory ->)
    buffer = IO::Memory.new

    yield buffer

    compressed_io = IO::Memory.new
    zlib_writer = Zlib::Writer.new(compressed_io)
    zlib_writer.write(buffer.to_slice)
    zlib_writer.close

    uncompressed_size = buffer.size
    compressed_size = compressed_io.size

    io.write_bytes(uncompressed_size, IO::ByteFormat::LittleEndian)

    if uncompressed_size <= compressed_size
      io.write_bytes(0, IO::ByteFormat::LittleEndian)
      buffer_bytes = buffer.to_slice
      compressed_io.close
      buffer.close
      io.write(buffer_bytes)
    else
      io.write_bytes(compressed_size, IO::ByteFormat::LittleEndian)
      compressed_bytes = compressed_io.to_slice
      compressed_io.close
      buffer.close
      io.write(compressed_io.to_slice)
    end
  end

  class BitWriter
    getter buffer = [] of UInt8
    getter cur : UInt8 = 0_u8
    getter bit_num = 0

    def initialize
    end

    def write_bit(state)
      @cur |= (state ? 1_u8 : 0_u8) << @bit_num
      @bit_num += 1
      align if @bit_num >= 8
    end

    def write_bits(source, length)
      length.times do |bit|
        write_bit((source[bit >> 3] & (1 << (bit & 7))) != 0)
      end
    end

    def write_bytes(source)
      write_bits(source, 8 * source.size)
    end

    def align
      if @bit_num > 0
        @buffer << @cur
        @cur = 0
        @bit_num = 0
      end
    end

    def write_int(value : Int32, max : Int32)
      raise WriteException.new("BitWriter max must be at least 2") unless max >= 2
      raise WriteException.new("BitWriter value is larger than max") if value >= max

      new_value = 0
      mask = 1

      while (new_value + mask) < max && mask != 0
        write_bit(value & mask != 0)
        new_value |= mask if value & mask != 0
        mask *= 2
      end
    end

    def write_packed_uint(value : UInt32)
      loop do
        source = [(value & 0b1111111).to_u8]
        value >>= 7
        write_bit(value != 0)
        write_bits(source, 7)
        break if value == 0_u32
      end
    end

    def write_packed_int(value : Int32)
      write_packed_uint((value.abs << 1).to_u32 | (value >= 0 ? 1 : 0))
    end

    def write_to(io : IO::Memory)
      align
      io.write(Bytes.new(@buffer.size) { |i| @buffer[i] })
    end
  end
end
