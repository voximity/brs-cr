module BRS
  enum Direction : UInt8
    XPositive
    XNegative
    YPositive
    YNegative
    ZPositive
    ZNegative
  end

  enum Rotation : UInt8
    Deg0
    Deg90
    Deg180
    Deg270
  end

  struct UVector3
    ZERO = UVector3.new(0, 0, 0)

    getter x : UInt32
    getter y : UInt32
    getter z : UInt32

    def self.new(bit_reader : Read::BitReader)
      self.new(x: bit_reader.read_packed_uint, y: bit_reader.read_packed_uint, z: bit_reader.read_packed_uint)
    end

    def self.new(x : Int32, y : Int32, z : Int32)
      self.new(x: x.to_u32, y: y.to_u32, z: z.to_u32)
    end

    def initialize(@x, @y, @z)
    end

    def write(writer : Write::BitWriter)
      writer.write_packed_uint @x
      writer.write_packed_uint @y
      writer.write_packed_uint @z
    end
  end

  struct Vector3
    ZERO = Vector3.new(0, 0, 0)

    getter x : Int32
    getter y : Int32
    getter z : Int32

    def self.new(bit_reader : Read::BitReader)
      self.new(x: bit_reader.read_packed_int, y: bit_reader.read_packed_int, z: bit_reader.read_packed_int)
    end

    def initialize(@x, @y, @z)
    end

    def write(writer : Write::BitWriter)
      writer.write_packed_int @x
      writer.write_packed_int @y
      writer.write_packed_int @z
    end
  end

  struct Color
    getter r : UInt8
    getter g : UInt8
    getter b : UInt8
    getter a : UInt8

    def self.new(slice : Bytes)
      self.new(r: slice[2], g: slice[1], b: slice[0], a: slice[3])
    end

    def self.new(io : IO)
      self.new(Bytes.new(4).tap { |slice| io.read(slice) })
    end

    def self.new(*, r : Int32, g : Int32, b : Int32, a : Int32)
      self.new(r: r.to_u8, g: g.to_u8, b: b.to_u8, a: a.to_u8)
    end

    def initialize(*, @r, @g, @b, @a)
    end

    def write(io : IO)
      io.write_byte(@b)
      io.write_byte(@g)
      io.write_byte(@r)
      io.write_byte(@a)
    end

    def write(writer : Write::BitWriter)
      writer.write_bytes([@b, @g, @r, @a])
    end
  end

  struct User
    getter username : String
    getter uuid : UUID

    def self.new(io : IO)
      uuid = Read.read_uuid(io)
      username = Read.read_string(io)
      self.new(username, uuid)
    end

    def initialize(@username, @uuid)
    end

    def write(io : IO)
      Write.write_uuid(io, @uuid)
      Write.write_string(io, @username)
    end
  end

  struct Brick
    getter asset_name_index : Int32
    getter size : UVector3
    getter position : Vector3
    getter direction : Direction = Direction::ZPositive
    getter rotation : Rotation = Rotation::Deg0
    getter collision : Bool = true
    getter visibility : Bool = true
    getter material_index : UInt32 = 2_u32
    getter color : Color?
    getter color_index : Int32?
    getter owner_index : UInt32? = nil

    def initialize(*,
                   @asset_name_index = 0,
                   @size,
                   @position,
                   @direction = Direction::ZPositive,
                   @rotation = Rotation::Deg0,
                   @collision = true,
                   @visibility = true,
                   @material_index = 2_u32,
                   @color = nil,
                   @color_index = nil,
                   @owner_index = nil)
    end
  end
end
