# frozen_string_literal: true
# typed: true

module Nightshift
  # Who created the thing: a nightshift skill, or a human.
  #
  # The distinction matters twice. The skill pipeline must keep looking only at
  # what it produced (no flooding on manual branches), while the inventory must
  # look at everything.
  class WorkItemOrigin < T::Enum
    enums do
      Auto    = new('auto')
      Manual  = new('manual')
      Unknown = new('unknown')
    end
  end
end
