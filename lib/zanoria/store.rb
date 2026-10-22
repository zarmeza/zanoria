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

    # The note's text, exactly as it is on disk.
    #
    # `load` prints the file rather than a parsed record, so it cannot use
    # `read`. It still comes through here, so that a note the tool cannot read
    # is reported the same way however it was asked for.
    def read_text(path)
      File.read(path)
    rescue SystemCallError => e
      raise Error, "could not read #{path}: #{e.message}"
    end

    def write(path, contents)
      File.write(path, contents)
      path
    rescue SystemCallError => e
      raise Error, "could not write #{path}: #{e.message}"
    end

    def delete(path)
      File.delete(path)
    rescue SystemCallError => e
      raise Error, "could not delete #{path}: #{e.message}"
    end

    # Read the note, falling back to an empty record when absent.
    def read_or_empty(path)
      File.exist?(path) ? read(path) : Record.new({}, path: path)
    end
  end
end
