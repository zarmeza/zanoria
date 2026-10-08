# frozen_string_literal: true

require 'fileutils'

module Zanoria
  # Reading and writing the note on disk.
  module Store
    module_function

    def read(path)
      Record.load(path)
    rescue SystemCallError => e
      raise Error, "could not read #{path}: #{e.message}"
    end

    def write(path, contents)
      File.write(path, contents)
      path
    rescue SystemCallError => e
      raise Error, "could not write #{path}: #{e.message}"
    end

    # Read the note, falling back to an empty record when absent.
    def read_or_empty(path)
      File.exist?(path) ? read(path) : Record.new({}, path: path)
    end
  end
end
