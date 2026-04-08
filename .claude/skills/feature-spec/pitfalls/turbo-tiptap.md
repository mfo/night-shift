---
triggers: [turbo, tiptap, prosemirror, stimulus, editeur, rich-text]
---
# TipTap + Turbo Stream

**Piege :** autosubmit (replace form entier) detruit l'instance ProseMirror — l'editeur devient inerte apres le premier turbo_stream replace.

**Solution :** Route dediee + turbo_stream cibles qui ne touchent pas le conteneur de l'editeur. Ne jamais remplacer le `<form>` parent d'un editeur TipTap.

**Pattern :**
```ruby
# Route dediee pour validation sans replace form
turbo_stream.replace "validation_result", partial: "validation_result"
# PAS turbo_stream.replace "form_container"
```

**Ref :** kaizen 2026-03-30 (referentiel-tiptap-url)
