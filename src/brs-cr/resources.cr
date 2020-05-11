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
    Zero
    Quarter
    Half
    ThreeQuarters
  end

  struct UVector3
    getter x : UInt32
    getter y : UInt32
    getter z : UInt32

    def self.new(bit_reader : Read::BitReader)
      self.new(x: bit_reader.read_packed_uint, y: bit_reader.read_packed_uint, z: bit_reader.read_packed_uint)
    end

    def initialize(@x, @y, @z)
    end
  end

  struct Vector3
    getter x : Int32
    getter y : Int32
    getter z : Int32

    def self.new(bit_reader : Read::BitReader)
      self.new(x: bit_reader.read_packed_int, y: bit_reader.read_packed_int, z: bit_reader.read_packed_int)
    end

    def initialize(@x, @y, @z)
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

    def initialize(*, @r, @g, @b, @a)
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
  end

  struct Brick
    getter asset_name_index : Int32
    getter size : UVector3
    getter position : Vector3
    getter direction : Direction = Direction::XPositive
    getter rotation : Rotation = Rotation::Zero
    getter collision : Bool = true
    getter visibility : Bool = true
    getter material_index : UInt32 = 1
    getter color : Color?
    getter color_index : Int32?
    getter owner_index : UInt32 = 0

    def initialize(*,
                   @asset_name_index = 0,
                   @size,
                   @position,
                   @direction = Direction::XPositive,
                   @rotation = Rotation::Zero,
                   @collision = true,
                   @visibility = true,
                   @material_index = 1,
                   @color = nil,
                   @color_index = nil,
                   @owner_index = 0)
    end
  end
end
