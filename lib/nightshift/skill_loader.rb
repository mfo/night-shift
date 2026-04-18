require "yaml"

module Nightshift
  module SkillLoader
    module_function

    def load(skill_name)
      path = skill_path(skill_name)
      content = File.read(path)
      frontmatter, body = parse_frontmatter(content)

      {
        name: frontmatter["name"],
        description: frontmatter["description"],
        allowed_tools: extract_tools(frontmatter),
        prompt: body
      }
    end

    def skill_path(name)
      nightshift_dir = File.expand_path("../../.claude/skills", __dir__)
      File.join(nightshift_dir, name, "SKILL.md")
    end

    def parse_frontmatter(content)
      match = content.match(/\A---\n(.+?)\n---\n(.*)/m)
      raise "Invalid SKILL.md: no frontmatter found" unless match
      yaml = YAML.safe_load(match[1], permitted_classes: [Symbol])
      raise "Invalid SKILL.md: malformed YAML frontmatter" unless yaml.is_a?(Hash)
      [yaml, match[2]]
    rescue Psych::SyntaxError => e
      raise "Invalid SKILL.md: #{e.message}"
    end

    def extract_tools(frontmatter)
      tools = frontmatter["allowed-tools"]
      case tools
      when String then tools
      when Array then tools.join(",")
      else ""
      end
    end
  end
end
