require "../src/brs-cr.cr"

brs_save = BRS::Save.new "input/Foshay Tower.brs"

brs_save.bricks.each do |brick|
  pp brick.size
  pp brick.position
  puts ""
end
