# RedisJSON Ruby Client [![Build Status](https://travis-ci.com/vachhanihpavan/rejson-rb.svg?token=x85KXUqPs5qJik1EzpyW&branch=master)](https://travis-ci.com/vachhanihpavan/rejson-rb)  [![Gem Version](https://badge.fury.io/rb/rejson-rb.svg)](https://badge.fury.io/rb/rejson-rb)

rejson-rb is a package that allows storing, updating and querying objects as JSON documents in a [Redis](https://redis.io/) database that is extended with the [ReJSON](https://github.com/RedisJSON/RedisJSON) module. The package extends redis-rb's interface with ReJSON's API, and performs on-the-fly serialization/deserialization of objects to/from JSON.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rejson-rb'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rejson-rb

## Usage

Make sure you have loaded rejson module in `redis.conf`
```ruby
require 'rejson'

rcl = Redis.new # Get a redis client

# Get/Set/Delete keys
obj = {
        'foo': 42,
        'arr': [nil, true, 3.14],
        'truth': {
          'coord': "out there"
        }
      }

rcl.json_set("root", Rejson::Path.root_path, obj)
# => "OK" 

rcl.json_set("root", Rejson::Path.new(".foo"), 56)
# => "OK" 

rcl.json_get "root", Rejson::Path.root_path
# => {"foo"=>56, "arr"=>[nil, true, 3.14], "truth"=>{"coord"=>"out there"}}

rcl.json_del "root", ".truth.coord"
# => 1

# Use similar to redis-rb client
rj = rcl.pipelined do
  rcl.set "foo", "bar"
  rcl.json_set "test", ".", "{:foo => 'bar', :baz => 'qux'}"
end
# => ["OK", "OK"] 
```

Path to JSON can be passed as `Rejson::Path.new("<path>")` or `Rejson::Path.root_path`. `<path>` syntax can be as mentioned [here](https://oss.redislabs.com/redisjson/path).

### Refer project WIKI for more detailed documentation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vachhanihpavan/rejson-rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/vachhanihpavan/rejson-rb/blob/master/CODE_OF_CONDUCT.md).

For complete documentation about ReJSON's commands, refer to ReJSON's website.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rejson project's codebase, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/vachhanihpavan/rejson-rb/blob/master/CODE_OF_CONDUCT.md).#
