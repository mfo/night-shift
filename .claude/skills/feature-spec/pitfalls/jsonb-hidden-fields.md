---
triggers: [jsonb, json, hidden_field, tiptap, prosemirror]
---
# JSONB + Hidden Fields

**Piege :** Les hidden fields envoient du JSON en string, pas un Hash. Sans custom setter, le model recoit une string brute et la persiste telle quelle (ou crashe).

**Solution :** Toujours prevoir un custom setter `field=` qui parse JSON string quand un hidden field alimente une colonne JSONB.

**Pattern :**
```ruby
def mon_champ_json=(value)
  super(value.is_a?(String) ? JSON.parse(value) : value)
rescue JSON::ParserError
  super(value)
end
```

**Ref :** kaizen 2026-03-30 (referentiel-tiptap-url)
