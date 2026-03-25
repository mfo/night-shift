# Kaizen -- Audit XSS complet en TDD (YWH-734019)
Date: 2026-03-20 | Skill: harden-audit, harden-fix | Score: ?/10

## Ce qui s'est passé

### Contexte
Rapport YesWeHack sur une faille XSS dans le email checker. L'utilisateur a demandé un fix TDD, puis un audit XSS exhaustif du codebase avec 5 agents en parallèle.

### Faille 1 — Email checker innerHTML (client + server)
- **Vecteur** : L'email `"<img src=x onerror=alert(1)>"@gmail.com` passe par `Mail::Address` (RFC 2822 quoted-string), le local part conserve le HTML
- **Côté client** : `email_input_controller.ts` utilisait `innerHTML` pour insérer la suggestion → exécution du HTML
- **Côté serveur** : `EmailChecker.suggestions` passait `parsed_email.local` tel quel → HTML dans la réponse JSON
- **Fix client** : `innerHTML` → `textContent` (3 endroits dans le controller)
- **Fix serveur** : `Rails::Html::FullSanitizer.new.sanitize(parsed_email.local)` avant de construire la suggestion
- **Piège rencontré** : `parsed_email.local` retourne le quoted-string avec le HTML intact, pas juste le texte

### Faille 2 — Prefill possible_values html_safe
- **Vecteur** : Un admin met `<img src=x onerror=alert(1)>` dans les `drop_down_options` d'un champ
- **Code vulnérable** : `PrefillTypeDeChamp#possible_values` faisait `.to_sentence` puis `.html_safe` sans échapper les valeurs individuelles
- **Fix** : `ERB::Util.html_escape` sur chaque valeur avant le `.to_sentence` et sur `description`
- **Audit** : Vérifié tous les sous-types de PrefillTypeDeChamp — seuls les types basés sur DropDownList ont des données user-controlled

### Faille 3 — MonAvis regex bypass
- **Vecteur** : Le HREF_CHECKER avait `monavis|voxusagers` sans groupe non-capturant → l'alternation matchait `monavis` OU `voxusagers.numerique.gouv.fr/...`, permettant n'importe quel domaine contenant "monavis" dans l'URL
- **Code vulnérable** : `HREF_CHECKER = /https:\/\/monavis|voxusagers.numerique.gouv.fr\/Demarches\/...`
- **Fix** : `(?:#{KNOWN_SUBDOMAIN.join('|')})` — groupe non-capturant pour l'alternation
- **Piège rencontré** : Le fix a aussi cassé un test existant (kthxbye) qui passait grâce au même bug regex → ajusté le test `eq` → `include`

### Faille 4 — Service faq_link / contact_link sans validation URL
- **Vecteur** : Un admin saisit `javascript:alert(1)` dans faq_link ou contact_link du Service
- **Code vulnérable** : Aucune validation URL sur ces champs — contrairement à `lien_dpo` et `lien_notice` qui avaient déjà `validates :xxx, url: { ... }`
- **Fix** : `validates :faq_link, url: { no_local: true, allow_blank: true }` et idem pour `contact_link`
- **Rendu** : Le footer usager affiche ces liens avec `link_to` → `javascript:` s'exécute au clic
- **Note** : Les liens ont `target="_blank" rel="noopener"` → le JS s'exécute dans un nouvel onglet, pas dans le contexte du domaine original. Phishing possible mais pas vol de session.

### Faille 5 — Procedure lien_dpo protocole dangereux
- **Vecteur** : `javascript:alert(document.domain)` dans `lien_dpo`
- **Code vulnérable** : `url_or_email_to_lien_dpo` dans `ProcedureHelper` retournait l'URL telle quelle si `Addressable::URI.parse` réussissait
- **Fix** : Allowlist `uri.scheme.in?(%w[http https])`, retourne `"#"` sinon
- **Exploitable en vrai ?** : **Non** — `lien_dpo` a déjà `validates :lien_dpo, url: { ... }` côté modèle. Le fix est défense en profondeur uniquement. Démontré seulement via `update_column` (bypass validations).
- **Rendu** : Le footer usager affiche ce lien **sans** `target="_blank"` → si exploitable, le JS s'exécute dans le même onglet/domaine

### Faille 6 — API token insertAdjacentHTML
- **Vecteur** : Un admin crée une procédure avec un libellé contenant du HTML, un co-admin crée un token API et sélectionne cette procédure
- **Code vulnérable** : `api_token_autorisation_controller.ts` utilisait `insertAdjacentHTML('beforeend', ...)` avec `option.text` (le libellé)
- **Fix** : Remplacement complet par DOM APIs (`createElement`, `textContent`, `append`)
- **Scénario** : Admin malveillant → co-admin victime (stored XSS inter-admin)

### Faille 7 — Tiptap tags innerHTML
- **Vecteur** : Un admin met du HTML dans un nom de champ, un instructeur utilise l'éditeur de messages et tape `--` pour insérer une balise
- **Code vulnérable** : `tiptap/tags.ts` utilisait `innerHTML` pour construire le menu de suggestions (hint text + boutons de balises)
- **Fix** : Remplacement complet par DOM APIs (`createElement`, `textContent`, `append`)
- **Scénario** : Admin malveillant → instructeur victime (stored XSS admin→instructeur)

### Faille bonus — cadre_juridique sans validation URL
- **Exploitable ?** : **Non** — la vue fait `starts_with?("http")` avant de rendre le lien
- **Fix** : `validates :cadre_juridique, url: { ... }` ajouté pour cohérence avec `lien_notice` et `lien_dpo`

### Démo Playwright
- Injecté `javascript:alert(document.domain)` dans `lien_dpo` de la procédure 142047 via `update_column`
- Authentifié via `/letter_opener` (magic link)
- Navigué vers `/dossiers/29943205` → footer → clic sur "Contacter le DPO" → alert "localhost" ✓
- Aussi visible dans le snapshot : `faq_link` et `contact_link` avaient `javascript:alert('kikoo')` et `javascript:void('kikoolol')`

### Feedback utilisateur clé
- **"Valider en entrée, pas sanitizer en sortie"** : L'utilisateur a rejeté le fix côté composant `ServiceListContactComponent` (safe_url method). La bonne approche est la validation modèle. Le fix composant + tests composant ont été supprimés.
- **Découpage en branches** : L'utilisateur a demandé 1 branche par sujet XSS → script `split_xss_branches.sh` avec worktrees + cherry-pick

## Ce qu'on a appris

### Expert OWASP A03 — Injection (XSS)
- **innerHTML/insertAdjacentHTML sont les puits XSS n°1 côté JS** : 3 failles sur 7 venaient de là. Règle simple : ne jamais injecter de donnée utilisateur via innerHTML. Toujours préférer textContent + createElement/append.
- **html_safe + to_sentence = piège classique** : quand on construit du HTML à la main en Ruby, chaque fragment doit être échappé individuellement AVANT le join/to_sentence, pas après.
- **RFC 2822 quoted-string est un vecteur inattendu** : `Mail::Address` parse `"<script>alert(1)</script>"@gmail.com` comme un email valide et conserve le HTML dans `.local`. Les parsers de standards (email, URL) peuvent retourner des données dangereuses.
- **Les regex sont des validateurs fragiles** : une alternation `a|b.foo` matche `a` OU `b.foo`, pas `(a|b).foo`. Toujours grouper avec `(?:...)`.

### Expert OWASP A04 — Insecure Design
- **Incohérence de validation = signal de faille** : `lien_dpo` et `lien_notice` avaient une validation URL mais pas `faq_link`, `contact_link`, ni `cadre_juridique` sur des modèles voisins. Quand un champ est validé, vérifier que tous les champs du même type le sont aussi.
- **Le vrai fix est toujours côté entrée** : sanitizer en sortie (composant, helper) est fragile car il faut le faire partout. Valider au modèle = une seule fois, impossible à contourner.
- **Vérifier avant de qualifier** : `lien_dpo` et `cadre_juridique` semblaient vulnérables mais étaient déjà protégés (validation modèle / guard `starts_with?`). Toujours vérifier la chaîne complète entrée→stockage→rendu avant de déclarer une faille exploitable.

### Expert OWASP A05 — Security Misconfiguration
- **`target="_blank" rel="noopener"` atténue mais ne bloque pas** : le JS s'exécute dans un nouvel onglet vide, pas dans le domaine de l'app. Pas de vol de cookie/session, mais phishing possible (la victime voit une page contrôlée par l'attaquant).
- **Sans `target="_blank"` c'est game over** : le lien DPO dans `_procedure_footer.html.haml` n'avait pas `target="_blank"` → `javascript:` s'exécutait dans le même onglet, même domaine, accès complet au DOM.
- **HttpOnly cookies = filet de sécurité** : même si XSS, `document.cookie` ne retourne pas le cookie de session. Mais l'attaquant peut toujours faire des requêtes authentifiées (CSRF-like via JS) ou modifier le DOM.

### Expert OWASP A07 — Process & Tooling
- **5 agents en parallèle pour l'audit** : scanner innerHTML, html_safe, link_to, regex, validators en parallèle accélère énormément la détection. Un agent par catégorie de vecteur.
- **TDD pour la sécurité** : test rouge qui prouve la faille → commit → fix → commit. Chaque faille a sa preuve reproductible dans la suite de tests.
- **Playwright pour la démo** : naviguer authentifié, cliquer sur le lien malveillant, capturer l'alert. Preuve visuelle irréfutable pour les stakeholders.
- **Worktree + cherry-pick pour le découpage** : une grosse branche d'audit → 6 branches atomiques, chacune avec son test + fix. Facilite la review et le merge indépendant.

## Action
- [ ] Documenter dans harden-fix la règle "valider en entrée > sanitizer en sortie" comme principe prioritaire → `.claude/skills/harden-fix/`
- [ ] Ajouter dans harden-audit une checklist des vecteurs XSS JavaScript : `innerHTML`, `insertAdjacentHTML`, `outerHTML`, `document.write` → `.claude/skills/harden-audit/`
- [ ] Ajouter dans harden-audit une checklist des vecteurs XSS Rails : `html_safe`, `raw()`, `link_to` avec URL user-controlled sans validation de protocole → `.claude/skills/harden-audit/`
- [ ] Ajouter dans harden-audit le réflexe de vérifier si la donnée est déjà validée en entrée avant de qualifier une faille (cf. lien_dpo, cadre_juridique)
- [ ] Documenter le pattern regex : toujours grouper les alternations `(?:a|b)` dans les validators → `.claude/skills/harden-audit/`
- [ ] Documenter le pattern worktree + cherry-pick pour découper une grosse branche de fix en PRs atomiques
- [ ] Ajouter `target="_blank" rel="noopener"` comme facteur atténuant (pas de vol de session, mais phishing) dans la grille d'évaluation DREAD
