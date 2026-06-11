# frozen_string_literal: true
# typed: true

module Nightshift
  class BacklogStatus < T::Enum
    enums do
      Pending = new('pending')
      Running = new('running')
      PrOpen  = new('pr_open')
      Done    = new('done')
      Failed  = new('failed')
      Skipped = new('skipped')
    end
  end
end
