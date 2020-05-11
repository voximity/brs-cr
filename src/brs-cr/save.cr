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
    property brick_assets : Array(String) = [] of String
    property colors : Array(Color) = [] of Color
    property materials : Array(String) = [] of String
    property brick_owners : Array(User) = [] of User

    property bricks : Array(Brick) = [] of Brick

    # Initialize a `Save` from a file path.
    def initialize(path : String)
      file = File.new(path)

      file.read(magic = Bytes.new(3))
      raise SaveException.new("Invalid starting bytes") unless magic.to_a == BRS::MAGIC

      @version = file.read_bytes(UInt16, IO::ByteFormat::LittleEndian)
      raise SaveException.new("Invalid save version #{@version}, must be at least 4") unless @version >= 4

      # read header 1
      header1 = Read.compression_reader(file)
      @map = Read.read_string(header1)
      author_name = Read.read_string(header1)
      @description = Read.read_string(header1)
      author_uuid = Read.read_uuid(header1)
      @author = User.new(author_name, author_uuid)
      @save_time = Read.read_time(header1)
      @brick_count = header1.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      header1.close unless header1.is_a?(File)

      # read header 2
      header2 = Read.compression_reader(file)
      @mods = Read.read_array(header2) { Read.read_string(header2) }
      @brick_assets = Read.read_array(header2) { Read.read_string(header2) }
      @colors = Read.read_array(header2) { Color.new(header2) }
      @materials = Read.read_array(header2) { Read.read_string(header2) }
      @brick_owners = Read.read_array(header2) { User.new(header2) }
      header2.close unless header2.is_a?(File)

      # read bricks
      brick_reader = Read.compression_reader(file)
      bit_reader = Read::BitReader.new(brick_reader)
      while !bit_reader.empty? && @bricks.size < @brick_count
        bit_reader.align
        asset_name_index = bit_reader.read_int [@brick_assets.size, 2].max
        size = bit_reader.read_bit ? UVector3.new(bit_reader) : UVector3.new(0_u32, 0_u32, 0_u32)
        position = Vector3.new(bit_reader)
        orientation = bit_reader.read_int 24
        direction = (orientation >> 2) % 6
        rotation = orientation % 3
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
          owner_index: owner_index
        )
      end

      file.close
    end
  end
end
