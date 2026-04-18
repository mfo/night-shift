require_relative "test_helper"
require_relative "../lib/nightshift/skill_loader"

class SkillLoaderTest < Minitest::Test
  def test_load_real_skill
    skill = Nightshift::SkillLoader.load("haml-migration")
    assert_equal "haml-migration", skill[:name]
    refute_empty skill[:allowed_tools]
    refute_empty skill[:prompt]
  end

  def test_load_test_optimization
    skill = Nightshift::SkillLoader.load("test-optimization")
    assert_equal "test-optimization", skill[:name]
    assert_includes skill[:allowed_tools], "Read"
    assert_includes skill[:allowed_tools], "Edit"
  end

  def test_extract_tools_array
    frontmatter = { "allowed-tools" => ["Read", "Edit", "Bash(git:*)"] }
    result = Nightshift::SkillLoader.extract_tools(frontmatter)
    assert_equal "Read,Edit,Bash(git:*)", result
  end

  def test_extract_tools_string
    frontmatter = { "allowed-tools" => "Read,Edit" }
    result = Nightshift::SkillLoader.extract_tools(frontmatter)
    assert_equal "Read,Edit", result
  end

  def test_extract_tools_missing
    frontmatter = {}
    result = Nightshift::SkillLoader.extract_tools(frontmatter)
    assert_equal "", result
  end

  def test_parse_frontmatter_no_frontmatter
    assert_raises(RuntimeError) do
      Nightshift::SkillLoader.parse_frontmatter("just markdown")
    end
  end

  def test_parse_frontmatter_valid
    content = "---\nname: test\ndescription: desc\n---\n# Body here"
    fm, body = Nightshift::SkillLoader.parse_frontmatter(content)
    assert_equal "test", fm["name"]
    assert_includes body, "# Body here"
  end
end
