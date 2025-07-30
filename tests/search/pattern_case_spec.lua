local Pattern = require("flash.search.pattern")
local Util = require("flash.util")
local assert = require("luassert")

describe("pattern case handling", function()
  describe("M._exact with case options", function()
    it("should add case-insensitive flag when ignorecase=true, smartcase=false", function()
      local case_options = { ignorecase = true, smartcase = false }
      local result = Pattern._exact("test", case_options)

      assert.equals("\\V\\ctest", result)
    end)

    it("should add case-sensitive flag when ignorecase=false", function()
      local case_options = { ignorecase = false, smartcase = true }
      local result = Pattern._exact("test", case_options)

      assert.equals("\\V\\Ctest", result)
    end)

    it("should apply smartcase logic for lowercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }
      local result = Pattern._exact("test", case_options)

      assert.equals("\\V\\ctest", result)
    end)

    it("should apply smartcase logic for uppercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }
      local result = Pattern._exact("Test", case_options)

      assert.equals("\\V\\CTest", result)
    end)

    it("should maintain backward compatibility when case_options is nil", function()
      local result = Pattern._exact("test", nil)

      assert.equals("\\Vtest", result)
    end)

    it("should handle empty patterns", function()
      local case_options = { ignorecase = true, smartcase = true }
      local result = Pattern._exact("", case_options)

      assert.equals("\\V\\c", result)
    end)

    it("should handle special regex characters", function()
      local case_options = { ignorecase = true, smartcase = false }
      local result = Pattern._exact("test.pattern[a-z]", case_options)

      assert.equals("\\V\\ctest.pattern[a-z]", result)
    end)
  end)

  describe("M._regex with case options", function()
    it("should add case-insensitive flag when ignorecase=true, smartcase=false", function()
      local case_options = { ignorecase = true, smartcase = false }
      local result = Pattern._regex("test.*", case_options)

      assert.equals("\\ctest.*", result)
    end)

    it("should add case-sensitive flag when ignorecase=false", function()
      local case_options = { ignorecase = false, smartcase = true }
      local result = Pattern._regex("test.*", case_options)

      assert.equals("\\Ctest.*", result)
    end)

    it("should apply smartcase logic for lowercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }
      local result = Pattern._regex("test.*", case_options)

      assert.equals("\\ctest.*", result)
    end)

    it("should apply smartcase logic for uppercase patterns", function()
      local case_options = { ignorecase = true, smartcase = true }
      local result = Pattern._regex("Test.*", case_options)

      assert.equals("\\CTest.*", result)
    end)

    it("should maintain backward compatibility when case_options is nil", function()
      local result = Pattern._regex("test.*", nil)

      assert.equals("test.*", result)
    end)
  end)

  describe("M._get with case options", function()
    it("should pass case options to exact mode", function()
      local case_options = { ignorecase = true, smartcase = true }
      local pattern, skip = Pattern._get("test", "exact", case_options)

      assert.equals("\\V\\ctest", pattern)
      assert.equals("\\V\\ctest", skip)
    end)

    it("should pass case options to regex mode", function()
      local case_options = { ignorecase = true, smartcase = false }
      local pattern, skip = Pattern._get("test.*", "regex", case_options)

      assert.equals("\\ctest.*", pattern)
      assert.equals("\\ctest.*", skip)
    end)

    it("should handle nil case_options gracefully", function()
      local pattern, skip = Pattern._get("test", "exact", nil)

      assert.equals("\\Vtest", pattern)
      assert.equals("\\Vtest", skip)
    end)
  end)

  describe("Pattern constructor with case options", function()
    it("should accept case_options parameter", function()
      local case_options = { ignorecase = true, smartcase = true }
      local pattern_obj = Pattern.new("test", "exact", nil, case_options)

      assert.is_not_nil(pattern_obj)
      assert.equals("test", pattern_obj.pattern)
      assert.same(case_options, pattern_obj.case_options)
    end)

    it("should maintain backward compatibility with 3-parameter constructor", function()
      local pattern_obj = Pattern.new("test", "exact", nil)

      assert.is_not_nil(pattern_obj)
      assert.equals("test", pattern_obj.pattern)
      assert.is_nil(pattern_obj.case_options)
    end)

    it("should use case options during pattern generation", function()
      local case_options = { ignorecase = true, smartcase = true }
      local pattern_obj = Pattern.new("Test", "exact", nil, case_options)

      -- The pattern should be generated with the case flag
      assert.equals("\\V\\CTest", pattern_obj.search)
    end)
  end)

  describe("M._fuzzy with case options", function()
    it("should add case-insensitive flag when ignorecase=true, smartcase=false", function()
      local opts = { ignorecase = true, smartcase = false }
      local result = Pattern._fuzzy("test", opts)

      assert.equals("\\V\\ct\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", result)
    end)

    it("should add case-sensitive flag when ignorecase=false", function()
      local opts = { ignorecase = false, smartcase = true }
      local result = Pattern._fuzzy("test", opts)

      assert.equals("\\V\\Ct\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", result)
    end)

    it("should apply smartcase logic for lowercase patterns", function()
      local opts = { ignorecase = true, smartcase = true }
      local result = Pattern._fuzzy("test", opts)

      assert.equals("\\V\\ct\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", result)
    end)

    it("should apply smartcase logic for uppercase patterns", function()
      local opts = { ignorecase = true, smartcase = true }
      local result = Pattern._fuzzy("Test", opts)

      assert.equals("\\V\\CT\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", result)
    end)

    it("should maintain backward compatibility when opts is nil", function()
      local result = Pattern._fuzzy("test", nil)

      -- Should use global vim settings
      local expected_flag = vim.go.ignorecase and "\\c" or "\\C"
      assert.equals("\\V" .. expected_flag .. "t\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", result)
    end)

    it("should handle whitespace option", function()
      local opts = { ignorecase = true, smartcase = false, whitespace = true }
      local result = Pattern._fuzzy("te st", opts)

      assert.equals("\\V\\ct.\\{-}e.\\{-} .\\{-}s.\\{-}t", result)
    end)

    it("should return skip pattern correctly", function()
      local opts = { ignorecase = true, smartcase = true }
      local pattern, skip = Pattern._fuzzy("test", opts)

      assert.equals("\\V\\ct\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t", pattern)
      assert.equals("\\V\\ct\\[^\\ ]\\{-}e\\[^\\ ]\\{-}s\\[^\\ ]\\{-}t\\[^\\ ]\\{-}", skip)
    end)
  end)

  describe("Integration with utility functions", function()
    it("should use Util.get_case_flag correctly", function()
      local case_options = { ignorecase = true, smartcase = true }

      -- Test lowercase (should be case-insensitive)
      local flag1 = Util.get_case_flag("test", case_options)
      assert.equals("\\c", flag1)

      -- Test uppercase (should be case-sensitive due to smartcase)
      local flag2 = Util.get_case_flag("Test", case_options)
      assert.equals("\\C", flag2)
    end)

    it("should work with resolved case options", function()
      -- Mock a mode config
      local mode_config = {
        search = {
          ignorecase = true,
          smartcase = true,
        },
      }

      local case_options = Util.resolve_case_options(mode_config)
      local result = Pattern._exact("test", case_options)

      assert.equals("\\V\\ctest", result)
    end)
  end)
end)
