# frozen_string_literal: true
# typed: true

module Nightshift
  # BacklogItem lifecycle: pending → running → pr_open → done (or failed/skipped)
  class BacklogStatus < T::Enum
    enums do
      Pending = new('pending')
      Running = new('running')
      PrOpen  = new('pr_open')
      Done    = new('done')
      Failed  = new('failed')
      Skipped = new('skipped')

      # Traite, sans rien produire. Distinct de `Done`, qui signifie « une PR a
      # ete ouverte, relue et mergee », et de `Skipped`, qui porte une charge
      # d'abandon dans tout le vocabulaire existant (ManualClose,
      # AutolearnExhausted, ResolvedUpstream) et que `backlog retry` traite
      # comme un echec a refaire.
      #
      # Un item `NoOp` a bien ete examine : le skill a conclu qu'il n'y avait
      # rien a faire, et sa justification est dans le cycle autolearn. Sans ce
      # statut, un fichier deja conforme ou une release sans impact doc
      # remontent en `Done` et gonflent les compteurs de reussite — un skill
      # qui ne produit jamais rien afficherait une progression parfaite.
      NoOp    = new('noop')
    end
  end
end
