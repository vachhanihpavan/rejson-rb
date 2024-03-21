# frozen_string_literal: true

module Rejson
  # Represents a Path in JSON value
  class Path
    attr_accessor :str_path

    def self.root_path
      root = Path.new(".")
      root
    end

    def self.json_root_path
      root = Path.new("$")
      root
    end

    def initialize(path)
      @str_path = path
    end
  end
end
