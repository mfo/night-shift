module Nightshift
  class Reconciler
    def initialize(store:, renderer:)
      @store = store
      @renderer = renderer
    end

    def reconcile(prs)
      prs.each do |pr|
        result = @store.reconcile_pr(pr)
        on_transition(pr, result[:old_state], result[:new_state]) if result[:changed]
        @renderer.update_window(pr)
      end
    end

    private

    def on_transition(pr, old_state, new_state)
      case [old_state, new_state]
      in [_, :ci_red]
        @renderer.autofix(pr)
      in [_, :approved]
        @renderer.propose_merge(pr)
      in [_, :has_comments | :changes_requested]
        @renderer.show_comments(pr)
      in [:ci_red, :ci_green]
        @renderer.notify_fixed(pr)
      else
        # noop
      end
    end
  end
end
