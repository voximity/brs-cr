require "uuid"
require "zlib"

require "./brs-cr/read.cr"
require "./brs-cr/resources.cr"
require "./brs-cr/save.cr"
require "./brs-cr/write.cr"

module BRS
  MAGIC = [66, 82, 83]
end
