# frozen_string_literal: true

# Handoff keeps a short, committed note about the task in progress so that a
# different agent tool can pick the work up without the conversation.
#
# The format is deliberately plain text. Any tool can read a markdown file, so
# nothing here depends on the agent that wrote it.
module CarrotHandoff
  FILENAME = '.carrot.md'

  # Convenience wrappers over the repo a note belongs to.
  module Repo
    module_function

    # Root of the repository, or nil when not inside one.
    def root
      Git.root
    end

    def path
      root = self.root
      raise CarrotHandoff::Error, 'not inside a git repository' unless root

      File.join(root, CarrotHandoff::FILENAME)
    end

    def exists?
      File.exist?(path)
    end

    # Current record, or nil when nothing has been saved yet.
    def current
      Store.read(path) if exists?
    end
  end

  # Base for errors this tool raises on its own behalf, as opposed to
  # surfacing a system or git failure verbatim.
  class Error < StandardError; end
end

require_relative 'carrot_handoff/version'
require_relative 'carrot_handoff/git'
require_relative 'carrot_handoff/record'
require_relative 'carrot_handoff/store'
require_relative 'carrot_handoff/template'
require_relative 'carrot_handoff/cli'
