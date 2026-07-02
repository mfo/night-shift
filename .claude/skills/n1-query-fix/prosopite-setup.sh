#!/bin/bash
# Setup Prosopite for N+1 detection in test mode (log, not raise)
# Idempotent — safe to run multiple times
set -e

# 1. Add gem if missing
if ! grep -q 'prosopite' Gemfile; then
  sed -i '' "/group :development, :test do/a\\
  gem 'prosopite'
" Gemfile
fi

if ! grep -q 'pg_query' Gemfile; then
  sed -i '' "/group :development, :test do/a\\
  gem 'pg_query'
" Gemfile
fi

# 2. bundle install (resolves Gemfile.lock automatically)
bundle install

# 3. Configure test.rb — log mode (not raise)
if ! grep -q 'Prosopite' config/environments/test.rb; then
  cat >> config/environments/test.rb <<'RUBY'

Rails.application.config.after_initialize do
  Prosopite.rails_logger = true
  Prosopite.raise = false
  Prosopite.prosopite_logger = Logger.new("tmp/prosopite-scan.log")
end
RUBY
fi

# 4. spec_helper.rb — scan hooks
if ! grep -q 'Prosopite.scan' spec/spec_helper.rb; then
  sed -i '' '/^end$/i\
\
  config.before(:each) { Prosopite.scan }\
  config.after(:each) { Prosopite.finish }
' spec/spec_helper.rb
fi
