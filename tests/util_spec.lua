local Util = require("flash.util")
local assert = require("luassert")

describe("util", function()
  describe("resolve_case_options", function()
    local original_ignorecase, original_smartcase

    before_each(function()
      -- Save original vim settings
      original_ignorecase = vim.go.ignorecase
      original_smartcase = vim.go.smartcase
    end)

    after_each(function()
      -- Restore original vim settings
      vim.go.ignorecase = original_ignorecase
      vim.go.smartcase = original_smartcase
    end)

    it("should use global vim settings as base", function()
      vim.go.ignorecase = true
      vim.go.smartcase = false

      local result = Util.resolve_case_options()

      assert.is_true(result.ignorecase)
      assert.is_false(result.smartcase)
    end)

    it("should prioritize mode config over global settings", function()
      vim.go.ignorecase = false
      vim.go.smartcase = false

      local mode_config = {
        search = {
          ignorecase = true,
          smartcase = true,
        },
      }

      local result = Util.resolve_case_options(mode_config)

      assert.is_true(result.ignorecase)
      assert.is_true(result.smartcase)
    end)

    it("should prioritize runtime overrides over mode config", function()
      vim.go.ignorecase = false
      vim.go.smartcase = false

      local mode_config = {
        search = {
          ignorecase = true,
          smartcase = false,
        },
      }

      local runtime_overrides = {
        ignorecase = false,
        smartcase = true,
      }

      local result = Util.resolve_case_options(mode_config, runtime_overrides)

      assert.is_false(result.ignorecase)
      assert.is_true(result.smartcase)
    end)

    it("should handle partial mode config", function()
      vim.go.ignorecase = false
      vim.go.smartcase = false

      local mode_config = {
        search = {
          ignorecase = true,
          -- smartcase not specified
        },
      }

      local result = Util.resolve_case_options(mode_config)

      assert.is_true(result.ignorecase)
      assert.is_false(result.smartcase) -- should use global setting
    end)

    it("should handle partial runtime overrides", function()
      vim.go.ignorecase = true
      vim.go.smartcase = false

      local runtime_overrides = {
        smartcase = true,
        -- ignorecase not specified
      }

      local result = Util.resolve_case_options(nil, runtime_overrides)

      assert.is_true(result.ignorecase) -- should use global setting
      assert.is_true(result.smartcase) -- should use override
    end)

    it("should handle invalid mode config gracefully", function()
      vim.go.ignorecase = true
      vim.go.smartcase = false

      local result = Util.resolve_case_options("invalid")

      assert.is_true(result.ignorecase)
      assert.is_false(result.smartcase)
    end)

    it("should handle invalid runtime overrides gracefully", function()
      vim.go.ignorecase = true
      vim.go.smartcase = false

      local result = Util.resolve_case_options(nil, "invalid")

      assert.is_true(result.ignorecase)
      assert.is_false(result.smartcase)
    end)

    it("should ignore non-boolean values in config", function()
      vim.go.ignorecase = true
      vim.go.smartcase = false

      local mode_config = {
        search = {
          ignorecase = "true", -- string instead of boolean
          smartcase = 1, -- number instead of boolean
        },
      }

      local result = Util.resolve_case_options(mode_config)

      assert.is_true(result.ignorecase) -- should use global setting
      assert.is_false(result.smartcase) -- should use global setting
    end)
  end)

  describe("should_ignore_case", function()
    it("should return false for invalid inputs", function()
      assert.is_false(Util.should_ignore_case(nil, {}))
      assert.is_false(Util.should_ignore_case("test", nil))
      assert.is_false(Util.should_ignore_case("test", "invalid"))
      assert.is_false(Util.should_ignore_case(123, {}))
    end)

    it("should return false when ignorecase is false", function()
      local case_options = { ignorecase = false, smartcase = true }

      assert.is_false(Util.should_ignore_case("test", case_options))
      assert.is_false(Util.should_ignore_case("Test", case_options))
      assert.is_false(Util.should_ignore_case("TEST", case_options))
    end)

    it("should respect ignorecase when smartcase is false", function()
      local case_options_ignore = { ignorecase = true, smartcase = false }
      local case_options_sensitive = { ignorecase = false, smartcase = false }

      assert.is_true(Util.should_ignore_case("test", case_options_ignore))
      assert.is_true(Util.should_ignore_case("Test", case_options_ignore))
      assert.is_false(Util.should_ignore_case("test", case_options_sensitive))
      assert.is_false(Util.should_ignore_case("Test", case_options_sensitive))
    end)

    it("should apply smartcase logic correctly", function()
      local case_options = { ignorecase = true, smartcase = true }

      -- lowercase patterns should ignore case
      assert.is_true(Util.should_ignore_case("test", case_options))
      assert.is_true(Util.should_ignore_case("hello world", case_options))
      assert.is_true(Util.should_ignore_case("123abc", case_options))

      -- patterns with uppercase should be case-sensitive
      assert.is_false(Util.should_ignore_case("Test", case_options))
      assert.is_false(Util.should_ignore_case("HELLO", case_options))
      assert.is_false(Util.should_ignore_case("helloWorld", case_options))
    end)

    it("should handle empty patterns", function()
      local case_options = { ignorecase = true, smartcase = true }

      assert.is_true(Util.should_ignore_case("", case_options))
    end)

    it("should handle special characters", function()
      local case_options = { ignorecase = true, smartcase = true }

      assert.is_true(Util.should_ignore_case("test.pattern", case_options))
      assert.is_true(Util.should_ignore_case("test[a-z]", case_options))
      assert.is_false(Util.should_ignore_case("Test.Pattern", case_options))
    end)

    it("should handle invalid case_options structure", function()
      assert.is_false(Util.should_ignore_case("test", { ignorecase = "true" }))
      assert.is_false(Util.should_ignore_case("test", { smartcase = true })) -- missing ignorecase
      assert.is_false(Util.should_ignore_case("test", { ignorecase = true })) -- missing smartcase
    end)
  end)

  describe("get_case_flag", function()
    it("should return case-insensitive flag for lowercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }

      assert.equals("\\c", Util.get_case_flag("test", case_options))
      assert.equals("\\c", Util.get_case_flag("hello world", case_options))
      assert.equals("\\c", Util.get_case_flag("", case_options))
    end)

    it("should return case-sensitive flag for uppercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }

      assert.equals("\\C", Util.get_case_flag("Test", case_options))
      assert.equals("\\C", Util.get_case_flag("HELLO", case_options))
      assert.equals("\\C", Util.get_case_flag("helloWorld", case_options))
    end)

    it("should return case-sensitive flag when ignorecase is false", function()
      local case_options = { ignorecase = false, smartcase = true }

      assert.equals("\\C", Util.get_case_flag("test", case_options))
      assert.equals("\\C", Util.get_case_flag("Test", case_options))
    end)

    it("should handle invalid inputs gracefully", function()
      assert.equals("\\C", Util.get_case_flag(nil, {}))
      assert.equals("\\C", Util.get_case_flag("test", nil))
      assert.equals("\\C", Util.get_case_flag("test", "invalid"))
    end)

    it("should work with ignorecase=true, smartcase=false", function()
      local case_options = { ignorecase = true, smartcase = false }

      assert.equals("\\c", Util.get_case_flag("test", case_options))
      assert.equals("\\c", Util.get_case_flag("Test", case_options))
      assert.equals("\\c", Util.get_case_flag("HELLO", case_options))
    end)
  end)

  describe("resolve_and_merge_case_options", function()
    it("should return original opts if no case options provided", function()
      local opts = { some_option = true }
      local result = Util.resolve_and_merge_case_options(opts, "search")

      assert.same(opts, result)
    end)

    it("should return nil if opts is nil", function()
      local result = Util.resolve_and_merge_case_options(nil, "search")

      assert.is_nil(result)
    end)

    it("should handle case options and merge them correctly", function()
      local opts = {
        ignorecase = true,
        smartcase = false,
        other_option = "value",
      }

      local result = Util.resolve_and_merge_case_options(opts, "search")

      -- Should have case options in search config
      assert.is_not_nil(result.search)
      assert.is_not_nil(result.search.case_options)
      assert.is_boolean(result.search.case_options.ignorecase)
      assert.is_boolean(result.search.case_options.smartcase)

      -- Should remove top-level case options
      assert.is_nil(result.ignorecase)
      assert.is_nil(result.smartcase)

      -- Should preserve other options
      assert.equals("value", result.other_option)
    end)

    it("should handle only ignorecase option", function()
      local opts = { ignorecase = false }

      local result = Util.resolve_and_merge_case_options(opts, "search")

      assert.is_not_nil(result.search.case_options)
      assert.is_nil(result.ignorecase)
    end)

    it("should handle only smartcase option", function()
      local opts = { smartcase = true }

      local result = Util.resolve_and_merge_case_options(opts, "search")

      assert.is_not_nil(result.search.case_options)
      assert.is_nil(result.smartcase)
    end)
  end)
end)
