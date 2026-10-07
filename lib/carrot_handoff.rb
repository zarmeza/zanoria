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

    # Where the note belongs: the repository root, or the current directory when
    # there is no repository.
    #
    # The cwd fallback is deliberate. Sessions do not always run inside a repo —
    # a `~/Developer` working directory, a scratch dir — and a note that refuses
    # to be written is the same as no note at all, which is the failure this tool
    # exists to prevent. A misplaced note is recoverable; a missing one is not.
    def root
      Git.root || Dir.pwd
    end

    # Whether a repository was found. The note is only durable when true: an
    # uncommitted file does not survive a machine swap.
    def in_repo?
      !Git.root.nil?
    end

    def path
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
