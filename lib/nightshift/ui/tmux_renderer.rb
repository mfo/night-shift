# frozen_string_literal: true

# DEPRECATED: replaced by Renderer (interface) + TmuxAdapter (implementation)
# This file kept for Zeitwerk autoloading compatibility.
# TODO: remove once all references are updated.

module Nightshift
  module UI
    TmuxRenderer = TmuxAdapter
  end
end
