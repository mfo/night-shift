require "open3"
require "json"

module Nightshift
  module Judge
    module_function

    VERDICTS = %w[skill_defect item_hard infra_error context_limit].freeze
    MAX_RETRIES = 3

    # Analyze a failed skill run and return a structured verdict.
    def evaluate(skill_name, item:, log_path:, failure_reason:)
      unless File.exist?(log_path)
        return fallback_verdict("log_missing", "Log file not found: #{log_path}")
      end

      # Inline the log content so the judge doesn't need file read permissions
      log_digest = extract_digest(log_path)
      prompt = build_prompt(skill_name, item, failure_reason, log_digest)
      raw = invoke_claude(prompt)
      parse_verdict(raw)
    rescue StandardError => e
      fallback_verdict("judge_error", e.message)
    end

    # Should this item be retried based on the verdict?
    def retryable?(verdict, retry_count)
      return false if retry_count >= MAX_RETRIES
      %w[skill_defect infra_error].include?(verdict[:verdict])
    end

    # Extract relevant signals from a stream-json log (avoid sending 5MB to the judge)
    def extract_digest(log_path, max_bytes: 50_000)
      errors = []
      last_events = []

      File.foreach(log_path) do |line|
        line.strip!
        next if line.empty?

        event = JSON.parse(line) rescue next

        # Collect errors
        if event["type"] == "user"
          content = event.dig("message", "content")
          if content.is_a?(Array)
            content.each do |block|
              if block["is_error"]
                errors << block["content"].to_s[0, 500]
              end
            end
          end
        end

        # Keep last N assistant/result events
        if %w[assistant result].include?(event["type"])
          text = extract_event_text(event)
          last_events << "[#{event['type']}] #{text}" if text && !text.empty?
          last_events.shift if last_events.size > 15
        end
      end

      parts = []
      parts << "=== ERRORS (#{errors.size}) ===" << errors.join("\n---\n") if errors.any?
      parts << "\n=== LAST EVENTS ===" << last_events.join("\n---\n")

      digest = parts.join("\n")
      digest.bytesize > max_bytes ? digest.byteslice(0, max_bytes) : digest
    end

    def extract_event_text(event)
      case event["type"]
      when "assistant"
        content = event.dig("message", "content")
        return nil unless content.is_a?(Array)
        content.filter_map { |b|
          case b["type"]
          when "text" then b["text"]
          when "tool_use" then "tool_use: #{b['name']}(#{b.dig('input', 'command') || b.dig('input', 'pattern') || '...'})"
          end
        }.join("\n")[0, 800]
      when "result"
        event["result"].to_s[0, 500]
      end
    end

    def build_prompt(skill_name, item, failure_reason, log_digest)
      <<~PROMPT
        Tu es un juge expert en analyse d'echecs de skills autonomes.

        ## Contexte

        Le skill "#{skill_name}" a echoue sur l'item "#{item}".
        Raison d'echec reportee : #{failure_reason}

        ## Log du run (digest)

        #{log_digest}

        ## Ta mission

        1. Analyse le log ci-dessus
        2. Identifie la cause racine de l'echec
        3. Classifie le verdict :
           - `skill_defect` : le prompt/skill est mal configure, il manque une instruction, un piege non documente
           - `item_hard` : cet item specifique est trop complexe ou a des particularites que le skill ne peut pas gerer
           - `infra_error` : erreur d'infrastructure (permission denied, serveur non demarre, DB non disponible, timeout)
           - `context_limit` : le modele a atteint la limite de turns/tokens sans converger

        4. Si le verdict est `skill_defect`, propose un patch concret (texte a ajouter dans patterns.md)

        ## Format de sortie OBLIGATOIRE

        Reponds UNIQUEMENT avec ce JSON, sans texte avant ou apres :

        ```json
        {
          "verdict": "skill_defect",
          "root_cause": "description concise de la cause racine",
          "fixable_by_skill_update": true,
          "suggested_patch": "texte a ajouter dans patterns.md ou null",
          "confidence": 0.8
        }
        ```
      PROMPT
    end

    def invoke_claude(prompt)
      out, status = Open3.capture2(
        "claude", "-p", prompt,
        "--output-format", "text",
        "--max-turns", "5"
      )
      unless status.success?
        return '{"verdict":"infra_error","root_cause":"judge claude process failed","fixable_by_skill_update":false,"suggested_patch":null,"confidence":0.1}'
      end
      out
    end

    def parse_verdict(raw)
      # Find the outermost JSON object containing "verdict"
      # Use a balanced brace approach instead of simple regex
      start_idx = raw.index("{")
      return fallback_verdict("parse_error", "No JSON found in judge output") unless start_idx

      depth = 0
      end_idx = nil
      (start_idx...raw.length).each do |i|
        case raw[i]
        when "{" then depth += 1
        when "}" then depth -= 1; if depth == 0 then end_idx = i; break; end
        end
      end
      return fallback_verdict("parse_error", "Unbalanced JSON in judge output") unless end_idx

      json_str = raw[start_idx..end_idx]
      data = JSON.parse(json_str)
      verdict = data["verdict"]
      unless VERDICTS.include?(verdict)
        return fallback_verdict("unknown_verdict", "Judge returned: #{verdict}")
      end

      {
        verdict: verdict,
        root_cause: data["root_cause"].to_s[0, 500],
        fixable_by_skill_update: !!data["fixable_by_skill_update"],
        suggested_patch: data["suggested_patch"],
        confidence: (data["confidence"] || 0.5).to_f.clamp(0.0, 1.0)
      }
    end

    def fallback_verdict(verdict_override, reason)
      {
        verdict: "infra_error",
        root_cause: "#{verdict_override}: #{reason}",
        fixable_by_skill_update: false,
        suggested_patch: nil,
        confidence: 0.0
      }
    end
  end
end
