module BRS
  extend self

  class SaveException < Exception
  end

  class Save
    property version : UInt16
    property map : String
    property description : String
    property author : User
    property save_time : Time = Time.utc
    property brick_count : Int32 = 0

    property mods : Array(String) = [] of String
    property brick_assets : Array(String) = ["PB_DefaultBrick"] of String
    property colors : Array(Color) = [] of Color
    property materials : Array(String) = ["BMC_Ghost", "BMC_Ghost_Fail", "BMC_Plastic", "BMC_Glow", "BMC_Metallic", "BMC_Hologram"] of String
    property brick_owners : Array(User) = [] of User

    property bricks : Array(Brick) = [] of Brick

    def initialize(
      @author,
      @version = 4_u16,
      @map = "Plate",
      @description = "brs-cr"
    )
    end

    # Initialize a `Save` from a file path.
    def initialize(io : IO, close_after = true)
      io.read(magic = Bytes.new(3))
      raise SaveException.new("Invalid starting bytes") unless magic.to_a == BRS::MAGIC

      @version = io.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      raise SaveException.new("Invalid save version #{@version}, must be at least 4") unless @version >= 4

      # read header 1
      header1 = Read.compression_reader(io)
      @map = Read.read_string(header1)
      author_name = Read.read_string(header1)
      @description = Read.read_string(header1)
      author_uuid = Read.read_uuid(header1)
      @author = User.new(author_name, author_uuid)
      @save_time = Read.read_time(header1)
      @brick_count = header1.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      header1.close if header1.is_a?(Zlib::Reader)

      # read header 2
      header2 = Read.compression_reader(io)
      @mods = Read.read_array(header2) { Read.read_string(header2) }
      @brick_assets = Read.read_array(header2) { Read.read_string(header2) }
      @colors = Read.read_array(header2) { Color.new(header2) }
      @materials = Read.read_array(header2) { Read.read_string(header2) }
      @brick_owners = Read.read_array(header2) { User.new(header2) }
      header2.close unless header2.is_a?(Zlib::Reader)

      io.seek(4, whence: IO::Seek::Current)

      # read bricks
      brick_reader = Read.compression_reader(io)
      bit_reader = Read::BitReader.new(brick_reader)
      while !bit_reader.empty? && @bricks.size < @brick_count
        bit_reader.align
        asset_name_index = bit_reader.read_int [@brick_assets.size, 2].max
        size = bit_reader.read_bit ? UVector3.new(bit_reader) : UVector3.new(0_u32, 0_u32, 0_u32)
        position = Vector3.new(bit_reader)
        orientation = bit_reader.read_int 24
        direction = (orientation >> 2) % 6
        rotation = orientation & 3
        collision = bit_reader.read_bit
        visibility = bit_reader.read_bit
        material_index = bit_reader.read_bit ? bit_reader.read_packed_uint : 1_u32
        color : Color? = nil
        color_index : Int32? = nil
        if bit_reader.read_bit
          color = Color.new(bit_reader.read_bytes(4))
        else
          color_index = bit_reader.read_int(@colors.size)
        end
        owner_index = bit_reader.read_packed_uint

        @bricks << Brick.new(
          asset_name_index: asset_name_index,
          size: size,
          position: position,
          direction: Direction.new(direction.to_u8),
          rotation: Rotation.new(rotation.to_u8),
          collision: collision,
          visibility: visibility,
          material_index: material_index,
          color: color,
          color_index: color_index,
          owner_index: owner_index == 0_u32 ? nil : owner_index - 1_u32
        )
      end

      io.close if close_after
    end

    def write(io : IO::Buffered)
      # Write the magic bytes
      io.write(Bytes.new(3) { |i| BRS::MAGIC[i].to_u8 })

      # Write the version
      io.write_bytes(4_u16, IO::ByteFormat::LittleEndian)

      # Header 1
      Write.write_compressed(io) do |io|
        Write.write_string(io, @map)
        Write.write_string(io, @author.username)
        Write.write_string(io, @description)
        Write.write_uuid(io, @author.uuid)
        Write.write_time(io, @save_time)
        io.write_bytes(@bricks.size, IO::ByteFormat::LittleEndian)
      end

      # Header 2
      Write.write_compressed(io) do |io|
        Write.write_array(io, @mods) { |item| Write.write_string(io, item) }
        Write.write_array(io, @brick_assets) { |item| Write.write_string(io, item) }
        Write.write_array(io, @colors, &.write(io))
        Write.write_array(io, @materials) { |item| Write.write_string(io, item) }
        Write.write_array(io, @brick_owners, &.write(io))
      end

      # Bricks
      Write.write_compressed(io) do |io|
        bit_writer = Write::BitWriter.new
        @bricks.each do |brick|
          bit_writer.align
          bit_writer.write_int(brick.asset_name_index, [@brick_assets.size, 2].max)
          if brick.size != UVector3::ZERO
            bit_writer.write_bit(true)
            brick.size.write(bit_writer)
          else
            bit_writer.write_bit(false)
          end
          brick.position.write(bit_writer)
          orientation = (brick.direction.value.to_i32 << 2) | (brick.rotation.value.to_i32)
          bit_writer.write_int(orientation, 24)
          bit_writer.write_bit(brick.collision)
          bit_writer.write_bit(brick.visibility)
          bit_writer.write_bit(brick.material_index != 1_u32)
          bit_writer.write_packed_uint(brick.material_index) if brick.material_index != 1_u32
          if brick.color.nil?
            raise SaveException.new("brick must have either color or color_index not nil") if brick.color_index.nil?
            bit_writer.write_bit(false)
            bit_writer.write_int(brick.color_index.not_nil!, [@colors.size, 2].max)
          else
            bit_writer.write_bit(true)
            brick.color.not_nil!.write(bit_writer)
          end
          bit_writer.write_packed_uint(brick.owner_index.nil? ? 0_u32 : brick.owner_index.not_nil! + 1)
        end
        bit_writer.write_to(io)
      end

      io.close # closes whether or not you like it
    end
  end
end
