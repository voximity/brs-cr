module BRS::Read
  extend self

  class ReadException < Exception
  end

  def compression_reader(io : IO) : IO
    uncompressed_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
    compressed_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)
    puts uncompressed_size
    puts compressed_size
    puts ""
    raise ReadException.new("Invalid compressed section size") if uncompressed_size < 0 || compressed_size < 0 || compressed_size >= uncompressed_size
    return io if compressed_size == 0
    Zlib::Reader.new(io, sync_close: false)
  end

  def read_string(io : IO) : String
    raw_size = io.read_bytes(Int32, IO::ByteFormat::LittleEndian)

    if raw_size > 0
      # Read the bytes
      bytes = Bytes.new(raw_size - 1)
      io.read(bytes)

      # Create a string
      string = String.new(bytes)

      # This byte must equal zero
      raise ReadException.new("String did not end with byte '0'") unless io.read_bytes(UInt8, IO::ByteFormat::LittleEndian) == 0_u8

      string
    else
      size = -raw_size
      raise ReadException.new("UCS-2 string has an invalid size") unless size % 2 == 0

      # Create a UTF-16 string. Note: BRS lib questions whether or not UTF-16 is backwards compatible with UCS-2
      String.from_utf16(Slice(UInt16).new(size // 2) { io.read_bytes(UInt16, IO::ByteFormat::LittleEndian) })
    end
  end

  def read_uuid(io : IO) : UUID
    io.read(slice = Bytes.new(16))
    groups = slice.to_a.in_groups_of(4).map(&.reverse)
    UUID.new(StaticArray(UInt8, 16).new { |i| groups[i // 4][i % 4].not_nil! })
  end

  def read_time(io : IO) : Time
    ticks = io.read_bytes(Int64, IO::ByteFormat::LittleEndian)
    seconds = ticks // 10_000_000_i64
    nanoseconds = ticks % 10_000_000 * 100
    Time.utc(seconds: seconds, nanoseconds: nanoseconds.to_i32)
  end

  def read_array(io : IO, &block : -> T) : Array(T) forall T
    Array(T).new(io.read_bytes(Int32, IO::ByteFormat::LittleEndian), &block)
  end

  class BitReader
    getter buffer : IO
    getter slice = Bytes.new(1)
    getter position = 0
    @empty = false

    protected def read_buffer
      num_read = @buffer.read(slice)
      @empty = num_read == 0
    end

    def empty?
      @empty
    end

    def byte
      slice[0]
    end

    def next_position
      @position += 1
      if position >= 8
        @buffer.read(slice)
        @position -= 8
      end
    end

    def align
      @buffer.read(slice) unless @position == 0
      @position = 0
    end

    def initialize(@buffer)
      @buffer.read(slice)
    end

    def read_bit
      bit = byte & (1 << @position)
      next_position
      bit == 1_u8
    end

    def read_int(max)
      value = 0
      mask = 1
      while value + mask < max && mask != 0
        value |= mask if read_bit
        mask <<= 1
      end
      value
    end

    def read_packed_uint
      value = 0_u32
      i = 0
      while i < 5
        bit = read_bit
        part = 0
        7.times do |shift|
          part |= (read_bit ? 1 : 0) << shift
        end
        value |= part << (7 * i)
        break unless bit
        i += 1
      end
      return value
    end

    def read_packed_int
      value = read_packed_uint
      (value >> 1).to_i32 * (value & 1 != 0 ? 1 : -1)
    end

    def read_bits(num)
      arr = Bytes.new((num / 8).ceil.to_i)
      num.times do |bit|
        shift = bit & 7
        arr[bit >> 3] = (arr[bit >> 3] & ~(1 << shift)) | ((read_bit ? 1 : 0) << shift)
      end
      arr
    end

    def read_bytes(num)
      read_bits(8 * num)
    end
  end
end
