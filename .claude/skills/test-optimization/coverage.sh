#!/usr/bin/env bash
# Usage: coverage.sh <spec_file>
# Runs a spec with COVERAGE=true and extracts the coverage %.
# Bypasses permission issues when called as a single allowed tool.
set -euo pipefail

spec_file="${1:?Usage: coverage.sh <spec_file>}"

rm -f coverage/.resultset.json
COVERAGE=true bundle exec spring rspec "$spec_file"

ruby -rjson -e '
  data = JSON.parse(File.read("coverage/.resultset.json"))
  touched = data.values.first["coverage"].select { |_path, info|
    info["lines"]&.any? { |l| l && l > 0 }
  }
  lines = touched.values.flat_map { |f| f["lines"] }.compact
  covered = lines.count { |l| l && l > 0 }
  total = lines.count { |l| !l.nil? }
  puts "Coverage: #{(covered.to_f / total * 100).round(2)}%"
'
