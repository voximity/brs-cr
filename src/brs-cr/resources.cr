module BRS
  DEFAULT_PALETTE = [
    0xffffffff, 0x888888ff, 0x595959ff, 0x393939ff, 0x232323ff, 0x111111ff, 0x060606ff, 0x000000ff, 0x570509ff, 0xea0606ff, 0xf64906ff, 0xea9d06ff, 0x088a05ff, 0x0498aaff, 0xa32355ff, 0x5a1237ff, 0x160401ff, 0x31140dff, 0x591004ff, 0x903c12ff, 0xa6683eff, 0xff9f4eff, 0xc2a33aff, 0xffaf2fff, 0x051205ff, 0x051e02ff, 0x152400ff, 0x004c00ff, 0x0b360aff, 0x434f0cff, 0xff920aff, 0x6d4005ff, 0x0a1e2bff, 0x1e2729ff, 0x475c60ff, 0x83acb5ff, 0x5093a2ff, 0x0876c8ff, 0x00407aff, 0x012240ff, 0xff0e0e99, 0xffcc0599, 0x1f901299, 0x2b85bd99, 0x57050999, 0xf6490699, 0x082b0f99, 0xffffff99, 0xffffff99, 0x88888899, 0x59595999, 0x39393999, 0x23232399, 0x11111199, 0x06060699, 0x00000099
  ].map { |n| Color.new(n.to_u32) }

  DEFAULT_MATERIALS = ["BMC_Ghost", "BMC_Ghost_Fail", "BMC_Plastic", "BMC_Glow", "BMC_Metallic", "BMC_Hologram"]

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

    def +(other : Vector3)
      Vector3.new(@x + other.x, @y + other.y, @z + other.z)
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

    def self.new(*, r : Int32, g : Int32, b : Int32, a : Int32 = 255)
      self.new(r: r.to_u8, g: g.to_u8, b: b.to_u8, a: a.to_u8)
    end

    def self.new(n : UInt32)
      self.new(
        r: ((n >> 24) & 0xFF).to_u8,
        g: ((n >> 16) & 0xFF).to_u8,
        b: ((n >> 8) & 0xFF).to_u8,
        a: (n & 0xFF).to_u8
      )
    end

    def initialize(*, @r, @g, @b, @a = 255_u8)
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

    protected def lerp(a : UInt8, b : UInt8, c : Float32)
      (a.to_f32 + (b.to_f32 - a.to_f32) * c).round.to_u8
    end

    def lerp(other : Color, c : Float32)
      Color.new(
        r: lerp(@r, other.r, c),
        g: lerp(@g, other.g, c),
        b: lerp(@b, other.b, c),
        a: lerp(@a, other.a, c)
      )
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
    getter size : UVector3 = UVector3::ZERO
    getter position : Vector3 = Vector3::ZERO
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
                   @size = UVector3::ZERO,
                   @position = Vector3::ZERO,
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
