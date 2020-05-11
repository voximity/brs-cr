require "bit_array"
require "flate"
require "uuid"
require "zlib"

require "./brs-cr/read.cr"
require "./brs-cr/resources.cr"
require "./brs-cr/save.cr"

module BRS
  MAGIC = [66, 82, 83]
end
