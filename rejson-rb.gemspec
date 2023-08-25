# frozen_string_literal: true

require "./lib/rejson/version"

Gem::Specification.new do |spec|
  spec.name          = "rejson-rb"
  spec.version       = Rejson::VERSION
  spec.authors       = ["Pavan Vachhani"]
  spec.email         = ["vachhanihpavan@gmail.com"]

  spec.summary       = "Redis JSON Ruby Client"
  spec.description   = "rejson-rb is a package that allows storing, updating and querying objects as JSON documents
                        in Redis database that is intended with RedisJSON module."
  spec.homepage      = "https://github.com/vachhanihpavan/rejson-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/vachhanihpavan/rejson-rb"
  spec.metadata["changelog_uri"] = "https://github.com/vachhanihpavan/rejson-rb"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "json",          "~> 2.0"
  spec.add_runtime_dependency "redis",         ">= 4.2.1", "<= 5.0.7"

  spec.add_development_dependency "bundler",   "~> 2.0"
  spec.add_development_dependency "rspec",     "~> 3.0"
  spec.add_development_dependency "rubocop",   "=0.86.0"
  spec.add_development_dependency "simplecov", "~> 0.17"
end
