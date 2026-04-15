# Patterns Harden — Failles et faux positifs validés

**Source :** Kaizens 2026-03-20 (7 failles XSS, 1 IDOR faux positif, 1 fix inutile)

---

## Pattern 1 : Faux positif — Protection downstream (Score 10/10)

### Contexte
Une faille semble exister au niveau controller, mais une protection existe plus loin dans la chaîne (service, model, DB).

### Symptôme
`Dossier.find(params[:id])` dans le controller → "pas de scope user !" Mais dans le service appelé ensuite : `current_user.dossiers.find(id)`.

### Règle
**Toujours tracer la chaîne complète AVANT de qualifier.** Voir Étape 2b du skill harden-audit.

### Exemple validé
```ruby
# Controller (semble vulnérable)
def show
  @dossier = Dossier.find(params[:id])
end

# Service appelé ensuite (protège en aval)
def authorized?(dossier)
  current_user.dossiers.include?(dossier)
end
# → Faux positif : protection au niveau service
```

### Impact si raté
Session entière gaspillée sur un fix inutile (~4-6h).

---

## Pattern 2 : Faux positif — IDs non-énumérables (Score 9/10)

### Contexte
IDOR détecté sur un `find(params[:id])` sans scope user, mais les IDs ne sont pas prédictibles.

### Symptôme
"User A peut accéder au dossier de User B via l'ID !" Mais l'ID est un UUID ou n'est exposé nulle part.

### Règle
**Un IDOR n'est exploitable que si l'attaquant peut obtenir/deviner l'ID.**

### Checklist
1. IDs auto-incrémentés ? (1, 2, 3...) → Énumérable, IDOR réel
2. IDs UUID/crypto ? → Brute-force impraticable, faux positif
3. IDs exposés publiquement (URL partagée, API response, sitemap) ? → Exploitable
4. IDs dans un email/notification ? → Exploitable si l'attaquant intercepte
5. Les données exposées sont-elles déjà publiques ? → Si oui, impact nul même avec ID prédictible (ex: structure d'un formulaire de procédure publiée = info publique → faux positif)

### Verdict
- Auto-increment + exposés + données sensibles = **IDOR réel 🔴**
- UUID + non exposés = **Faux positif 🟢**
- Données déjà publiques (quel que soit l'ID) = **Faux positif 🟢**

---

## Pattern 3 : XSS JavaScript — innerHTML/insertAdjacentHTML (Score 9/10)

### Contexte
3 failles XSS sur 7 dans un audit venaient de `innerHTML` ou `insertAdjacentHTML` en JavaScript.

### Patterns de recherche
```bash
grep -rn "insertAdjacentHTML\|innerHTML\|outerHTML\|document\.write" app/javascript/
```

### Règle
**Jamais injecter de données user via ces APIs.** Préférer textContent + createElement.

### Fix pattern
```typescript
// ❌ Dangereux
element.insertAdjacentHTML('beforeend', userInput)

// ✅ Sûr
const span = document.createElement('span')
span.textContent = userInput
element.append(span)
```

### Applicable à
Tout fichier JS/TS qui construit du HTML dynamiquement.

---

## Pattern 4 : XSS Rails — html_safe + to_sentence (Score 9/10)

### Contexte
Construire du HTML à la main en Ruby avec `html_safe` et `to_sentence` → piège classique.

### Symptôme
```ruby
values.to_sentence.html_safe  # ❌ Si values contient du HTML malveillant
```

### Règle
**Échapper CHAQUE fragment AVANT le join/to_sentence, pas après.**

### Fix pattern
```ruby
# ❌ Dangereux
values.to_sentence.html_safe

# ✅ Sûr
values.map { |v| ERB::Util.html_escape(v) }.to_sentence.html_safe
```

### Patterns de recherche
```bash
grep -rn "\.html_safe\|raw(" app/views/ app/helpers/ app/components/
grep -rn "to_sentence.*html_safe" app/
```

---

## Pattern 5 : Regex alternation non-groupée (Score 8/10)

### Contexte
Faille XSS via regex de validation qui n'utilise pas de non-capturing group.

### Symptôme
```ruby
# Matche "monavis" OU "button.numerique.gouv.fr"
# Donc "evil.com" passe si suivi de "button.numerique.gouv.fr"
/monavis.numerique.gouv.fr|button.numerique.gouv.fr/
```

### Règle
**Toujours grouper les alternations avec `(?:...)`.**

### Fix pattern
```ruby
# ❌ Dangereux
/monavis.numerique.gouv.fr|button.numerique.gouv.fr/

# ✅ Sûr
/(?:monavis|button)\.numerique\.gouv\.fr/
```

### Patterns de recherche
```bash
grep -rn "validates.*format\|=~ /.*|" app/models/
```

---

## Pattern 6 : Parsers dangereux — RFC 2822 quoted-string (Score 7/10)

### Contexte
`Mail::Address` parse `"<script>alert(1)</script>"@gmail.com` comme valide et conserve le HTML dans `.local`.

### Règle
**Les parsers standards (email, URL, JSON) peuvent retourner des données dangereuses.** Sanitizer après parsing.

### Patterns de recherche
```bash
grep -rn "Mail::Address\|Addressable::URI" app/
```

### Fix pattern
```ruby
# ❌ Dangereux
parsed_email.local  # peut contenir HTML

# ✅ Sûr
ERB::Util.html_escape(parsed_email.local)
```

---

## Pattern 7 : Faux positif — before_action héritée du parent (Score 8/10)

### Contexte
Un controller enfant hérite des `before_action` du parent. L'agent qui lit seulement le controller enfant peut croire qu'il n'y a pas de guard.

### Symptôme
`DossiersController` sans `before_action :authenticate_user!` visible → "pas d'authentification !" Mais `ApplicationController` (parent) l'a.

### Règle
**Toujours remonter la chaîne d'héritage** des controllers pour chercher les before_action hérités.

### Vérification
```bash
# Identifier le parent
grep -n "class DossiersController < " app/controllers/
# Lire les before_action du parent
grep -n "before_action" app/controllers/application_controller.rb
```

### Verdict
Si le parent a le before_action → faux positif.

---

## Pattern 8 : Faux positif — Scope implicite STI/default_scope (Score 7/10)

### Contexte
Un `Model.find(params[:id])` peut être sûr si le modèle a un `default_scope` qui filtre automatiquement, ou si STI (Single Table Inheritance) restreint le type.

### Règle
**Vérifier les scopes par défaut du modèle** avant de conclure à un IDOR.

### Vérification
```bash
grep -n "default_scope\|scope :.*where" app/models/<model>.rb
```

---

## Pattern 9 : Faux positif — Rate limiting comme mitigation IDOR (Score 6/10)

### Contexte
Un IDOR sur IDs auto-incrémentés AVEC rate limiting fort (Rack::Attack, 5 req/min par IP) est fortement mitigé. L'énumération devient impraticable.

### Règle
**Rate limiting ne supprime pas le bug, mais réduit drastiquement l'exploitabilité.** Score Exploitability = 1 si rate limiting strict est en place.

### Vérification
```bash
grep -rn "Rack::Attack\|throttle\|rate_limit" config/initializers/
```

---

## Pattern 10 : Faux positif — CSP/DOMPurify centralisé neutralise XSS (Score 6/10)

### Contexte
Une XSS "confirmée" dans un composant peut être neutralisée par un Content-Security-Policy strict (pas d'inline scripts) ou un DOMPurify global côté client.

### Règle
**Vérifier les headers de sécurité et sanitization globale avant de confirmer une XSS.**

### Vérification
```bash
grep -rn "Content-Security-Policy\|DOMPurify\|sanitize" config/ app/javascript/
```

---

## Pattern 11 : Faux positif — Validation DB compense l'absence de validation modèle (Score 5/10)

### Contexte
Un modèle sans `validates :field` peut avoir une contrainte DB (`NOT NULL`, `CHECK`, longueur max). L'agent qui ne lit que le modèle conclut "pas de validation".

### Règle
**Vérifier le schéma DB** (`db/schema.rb`) pour les contraintes quand le modèle semble ne pas valider.

### Vérification
```bash
grep -n "<column_name>" db/schema.rb
```

---

## Pattern 12 : Faux positif — Fragment cache avec valeur sanitizée (Score 4/10)

### Contexte
Un fragment vulnérable peut être rendu dans un contexte cachable (fragment cache Rails), où la valeur malveillante est overridée par une valeur sanitizée en cache.

### Règle
**Vérifier si le rendu est caché** avant de confirmer une XSS sur une vue.

### Applicable si
`cache do ... end` entoure le fragment potentiellement vulnérable.

---

## Pattern 13 : IDOR atténué par exposition by-design (Score 7/10)

### Contexte
Un IDOR est réel (chaîne non protégée, IDs prédictibles), mais les données "fuitées" sont déjà accessibles via une autre action du même controller ou une page publique.

### Symptôme
`ProceduresController#detail` expose les emails des admins via un `find` non scopé. Mais `#all` et `#administrateurs` exposent déjà ces mêmes emails pour les procédures publiées.

### Règle
**Avant de scorer Damage, vérifier ce qui est DÉJÀ exposé by design sur la même surface.** Le delta réel = nouvelle exposition - exposition existante. Si le delta est nul → Damage = 1 (hardening, pas security).

### Vérification
```bash
# Lister les autres actions du même controller
grep -n "def " app/controllers/<controller>.rb
# Pour chaque action : quelles données sont rendues dans la vue ?
```

### Verdict
- Delta > 0 (nouvelles données sensibles exposées) = **IDOR réel 🔴**, scorer le Damage sur le delta
- Delta = 0 (mêmes données déjà accessibles) = **Hardening 🟡**, Damage = 1, catégorie `hardening`

---

## Pattern 14 : Faux positif — Lookup non scopé intentionnel (Score 8/10)

### Contexte
Un `find(params[:id])` sans scope user est signalé comme IDOR, mais le nom du helper ou de la méthode indique explicitement que l'absence de scope est délibérée.

### Symptôme
`procedure_without_control` fait un `Procedure.find(params[:id])` non scopé → "IDOR !" Mais le nom `without_control` signale une intention : c'est une feature (ex: page admin "Toutes les démarches").

### Signaux d'intention
- Noms explicites : `without_control`, `public_`, `all_visible`, `unscoped_`, `global_`
- Le controller est dans un namespace admin/plateforme
- L'action est documentée comme consultation cross-organisation

### Règle
**Si le nom de la méthode/helper signale explicitement l'absence de scope, c'est un choix de design, pas un oubli.** Vérifier le contexte métier (Étape 0) avant de qualifier.

### Verdict
- Nom explicite + contexte admin/public + données non sensibles = **Faux positif 🟢**
- Nom explicite MAIS données sensibles exposées à un rôle non autorisé = **Faille réelle 🔴** (le nommage n'excuse pas tout)

---

## Anti-patterns

### Anti 1 : Qualifier sans tracer la chaîne
"Le controller n'a pas de scope user → IDOR !" → Mais le service en aval scope.

### Anti 2 : Oublier l'énumérabilité pour IDOR
"find(params[:id]) sans scope → exploitable !" → Mais IDs sont des UUID.

### Anti 3 : Fixer en sortie plutôt qu'en entrée
"Ajouter un helper safe_url dans le composant" → Non. Valider au modèle, une seule fois, impossible à contourner.

### Anti 4 : Ignorer la hiérarchie de classes
Faille sur `DropDownList.prefill_values` → existe aussi sur `Repetition.prefill_values` (même parent). Toujours vérifier les sœurs.
