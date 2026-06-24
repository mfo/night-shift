# frozen_string_literal: true

# DEPRECATED: iTerm2 integration now uses TmuxAdapter with mode: :cc (tmux -CC).
# This file kept for Zeitwerk autoloading compatibility.
# TODO: remove once confirmed unused.

module Nightshift
  module UI
    class Iterm2Adapter < TmuxAdapter
      def initialize(session: ENV.fetch('NIGHTSHIFT_SESSION'))
        super(session: session, mode: :cc)
      end
    end
  end
end
