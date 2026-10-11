# frozen_string_literal: true

module Zanoria
  # The easter egg.
  #
  # The name is a joke from San Rafael de Mucuchíes: a campesino drops a carrot,
  # which by local superstition means somebody is thinking of him, and the
  # mishearing — *zanahoria* read as *sanoria*, Cecilia spelled *Secilia* — is
  # the clue he reasons from rather than a typo. So the art tells the whole
  # thing: the drop, the superstition, and the peasant working out that Cecilia
  # is the one thinking of him.
  #
  # The cow is described rather than drawn, in the third person, which is the
  # joke as much as the punchline is — it keeps the art about the reasoning and
  # lets the moo be something the reader supplies.
  #
  # Nothing here reads or writes anything. No note, no git, no repository state:
  # a command run to be amused should not leave a mark on the tree it ran in.
  # That is also why it is absent from `USAGE` — an easter egg listed in the
  # command table is a feature, and this is not one. The spec pins both
  # properties, because neither survives a well-meaning tidy-up on its own.
  module Moo
    # Quoted heredoc, `<<~'ART'`, and the quoting is load-bearing. In an
    # interpolating heredoc `\ ` is an escape sequence, so the backslashes are
    # eaten, and the only symptom is a drawing that is subtly wrong in a way no
    # assertion about *content* would ever catch. The spec compares the backslash
    # count against this source block rather than matching literal strings, so
    # it survives the art being redrawn.
    ART = <<~'ART'
                       ___
               `-._\ /     `~~"--.,_
              ------>|              `~~"--.,_
               _.-'/ '.____,,,,----"""~~```'

      "Se me cayó la zanoria... Me pensaron por la S,
      sería Secilia?..."

      (Pretend there's a cow in the background and she just mooed)

    ART

    module_function

    def render
      ART
    end
  end
end
