# brs-cr

brs-cr is a port of the [Brickadia](https://brickadia.com/) [brs](https://github.com/brickadia/brs) save (de)serializer.

Only supports versions 4+.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     brs-cr:
       github: your-github-user/brs-cr
   ```

2. Run `shards install`

## Usage

```cr
require "brs-cr"

me = BRS::User.new(username: "x", uuid: UUID.new("3f5108a0-c929-4e77-a115-21f65096887b"))

save = BRS::Save.new(
  author: me,
  description: "generated save file"
)

16.times do |y|
  16.times do |x|
    save.bricks << BRS::Brick.new(
      size: BRS::UVector3.new(5, 5, 2),
      position: BRS::Vector3.new(5 + x * 10, 5 + y * 10, 2),
      color_index: Random.rand(0...save.colors.size)
    )
  end
end

save.write(File.new("input/out.brs", mode: "w"))
```

## Contributing

1. Fork it (<https://github.com/your-github-user/brs-cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Credits

- [voximity](https://github.com/voximity) - creator and maintainer
- [Meshiest](https://github.com/Meshiest) - [brs-js](https://github.com/Meshiest/brs-js) for reference
- [Brickadia](https://github.com/brickadia) - game and format
