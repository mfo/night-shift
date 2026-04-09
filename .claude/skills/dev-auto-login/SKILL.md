---
name: dev-auto-login
description: "Setup dev auto-login and ViewComponent reload. Use for localhost authentication setup."
allowed-tools: Bash(grep:*), Bash(touch:*), Edit(config/*), Write(config/*)
---

# Auto-login dev

**Contexte :** Certains skills ont besoin de naviguer sur `localhost:3000` en étant authentifié (screenshots, tests visuels, démo). Plutôt que de patcher `ApplicationController` et risquer de commiter le patch, on utilise un initializer séparé qui rouvre la classe — git-ignoré.

**Fichier :** `config/initializers/dev_auto_login.rb`

## Setup

**1. Vérifier que le fichier est git-ignoré** dans le repo cible (`.gitignore` doit contenir `config/initializers/dev_auto_login.rb`). Si ce n'est pas le cas → prévenir l'utilisateur et ajouter l'entrée AVANT de créer le fichier.

**2. Vérifier si le fichier existe déjà :**
```bash
grep -l auto_sign_in_dev_user config/initializers/dev_auto_login.rb
```

**3. Si absent → le créer :**

```ruby
# config/initializers/dev_auto_login.rb
# ⚠️ Git-ignoré — auto-login dev + reload ViewComponent
# Rouvre ApplicationController pour ajouter le auto-login sans modifier le fichier original.
return unless Rails.env.development?

Rails.application.config.to_prepare do
  # Auto-login
  ApplicationController.class_eval do
    prepend_before_action :auto_sign_in_dev_user

    def auto_sign_in_dev_user
      return if user_signed_in?
      raise "[dev_auto_login] ENV['DEV_EMAIL'] non définie — auto-login désactivé" if ENV['DEV_EMAIL'].empty?
      user = User.find_by(email: ENV['DEV_EMAIL'])
      sign_in(user, scope: :user)
      current_user.instructeur&.update(bypass_email_login_token: true)
    end
  end

  # Invalidation cache ViewComponent — permet de switcher .haml → .erb sans redémarrer le serveur
  ViewComponent::CompileCache.invalidate!

  ObjectSpace.each_object(Class).select { |klass| klass < ViewComponent::Base }.each do |klass|
    if klass.instance_variable_defined?(:@__vc_compiler)
      compiler = klass.instance_variable_get(:@__vc_compiler)
      compiler.instance_variable_set(:@templates, nil) if compiler.instance_variable_defined?(:@templates)
    end
  end
end
```

**4. Redémarrer le serveur** pour charger l'initializer :
```bash
touch tmp/restart.txt
```

## Désactivation

Supprimer ou renommer le fichier. Rien d'autre à faire — `ApplicationController` n'a jamais été modifié.
