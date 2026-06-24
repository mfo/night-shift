# frozen_string_literal: true
# typed: true

module Nightshift
  # Computed PR state derived from CI, review, and merge status (priority-ordered)
  class PRState < T::Enum
    enums do
      Deployed          = new('deployed')
      Merged            = new('merged')
      Closed            = new('closed')
      CiRed             = new('ci_red')
      ChangesRequested  = new('changes_requested')
      AutoMerging       = new('auto_merging')
      Approved          = new('approved')
      HasComments       = new('has_comments')
      CiGreen           = new('ci_green')
      CiRunning         = new('ci_running')
      Draft             = new('draft')
    end
  end
end
