local lib = require('cmp_nvim_wikilinks')

describe('cmp_wikilinks', function()
  describe('._get_completion_pattern', function()
    it('returns nil if the cursor is not within a full or partial link', function()
      assert.is_nil(lib._get_completion_pattern('hello', 3), 'no link on line (simple)')
      assert.is_nil(lib._get_completion_pattern('and [[foo]] bar', 3), 'not in link (before, simple)')
      assert.is_nil(lib._get_completion_pattern('and [[foo]] bar', 13), 'not in link (after, simple)')
      assert.is_nil(lib._get_completion_pattern('hello [[open-link', 3), 'not in open link (before, simple)')

      assert.is_nil(lib._get_completion_pattern('and [[foo/okay/sg]] bar', 3), 'not in link (before, with paths)')
      assert.is_nil(lib._get_completion_pattern('and [[foo/okay/sg]] bar', 20), 'not in link (after, with paths)')
      assert.is_nil(lib._get_completion_pattern('hello [[open-link/to-somewhere', 3),
        'not in open link (before, with paths)')
    end)

    it('returns the pattern for open links at the end of the line', function()
      assert.equals('foo', lib._get_completion_pattern('see [[foo', 10), 'end of open link at end of line')
      assert.equals('fo', lib._get_completion_pattern('see [[foo', 9), 'open link at end of line')
      assert.equals('f', lib._get_completion_pattern('see [[not this one]] [[foo', 25),
        'open link at end of line with preceeding link')
      assert.equals('foo', lib._get_completion_pattern('see [[not this one]] [[foo', 27),
        'end of open link at end of line with preceeding link')

      assert.equals('foo/bar', lib._get_completion_pattern('see [[foo/bar', 14),
        'end of open link at end of line (with path)')
      assert.equals('foo/ba', lib._get_completion_pattern('see [[foo/bar', 13), 'open link at end of line (with path)')
      assert.equals('foo/b', lib._get_completion_pattern('see [[not this one]] [[foo/bar', 29),
        'open link at end of line with preceeding link (with path)')
      assert.equals('foo/bar', lib._get_completion_pattern('see [[not this one]] [[foo/bar', 31),
        'end of open link at end of line with preceeding link (with path)')
    end)

    it('returns the pattern for open links in the middle of the line', function()
      assert.equals('foo', lib._get_completion_pattern('see [[foo but not [[bar]]', 10), 'open link mid-line')
      assert.equals('foo b', lib._get_completion_pattern('see [[foo but not [[bar]]', 12),
        'open link mid-line with spaces')

      assert.equals('foo/bar', lib._get_completion_pattern('see [[foo/bar but not [[bar]]', 14),
        'open link mid-line (with path)')
      assert.equals('foo/bar b', lib._get_completion_pattern('see [[foo/bar but not [[bar]]', 16),
        'open link mid-line with spaces (with path)')
    end)

    it('returns the pattern for links', function()
      assert.equals('foo', lib._get_completion_pattern('see [[foo]] or perhaps [[bar]] i dunno', 10), 'full first link')
      assert.equals('bar', lib._get_completion_pattern('see [[foo]] or perhaps [[bar]] i dunno', 29),
        'full subsequent link (with path)')
      assert.equals('bar', lib._get_completion_pattern('see [[foo but not [[bar]]', 24), 'full link following open link')

      assert.equals('foo/bar', lib._get_completion_pattern('see [[foo/bar]] or perhaps [[bar]] i dunno', 14),
        'full first link (with path)')
      assert.equals('bar/bar', lib._get_completion_pattern('see [[foo]] or perhaps [[bar/bar]] i dunno', 33),
        'full subsequent link (with path)')
      assert.equals('bar/bar', lib._get_completion_pattern('see [[foo but not [[bar/bar]]', 28),
        'full link following open link (with path)')
    end)
  end)

  describe('._unambiguous_abbreviations', function()
    it('returns the list of unambiguous relative path for item in paths', function()
      local item = '/home/user/vault/projects/rust.md'
      local paths = {
        '/home/user/vault',
        '/home/user/vault/projects',
        '/home/user/vault/refs',
      }
      local items = {
        '/home/user/vault/refs/',
        '/home/user/vault/projects/rust.md',
        '/home/user/vault/refs/rust.md',
      }
      assert.same({ 'projects/rust.md' }, lib._unambiguous_abbreviations(item, paths, items))
    end)

  end)

  describe('._shorten_item', function()
    local suffixesadd

    before_each(function()
      suffixesadd = vim.o.suffixesadd
      vim.o.suffixesadd = '.md'
    end)

    after_each(function()
      vim.o.suffixesadd = suffixesadd
    end)

    it('returns the shorterst unambiguous relative path for item in paths', function()
      local item = '/home/user/vault/projects/rust.md'
      local paths = {
        '/home/user/vault',
        '/home/user/vault/projects',
        '/home/user/vault/refs',
      }
      local items = {
        '/home/user/vault/refs/',
        '/home/user/vault/projects/rust.md',
        '/home/user/vault/refs/rust.md',
      }
      assert.equals('projects/rust', lib._shorten_item(item, paths, items))
    end)

    it('falls back to path relative to cwd when all matches are ambiguous', function()
      local item = '/home/user/vault/projects/rust.md'
      local paths = {
        '/home/user/vault',
        '/home/user/vault/projects',
        '/home/user/vault/refs',
        '/home/user/vault/refs/projects',
      }
      local items = {
        '/home/user/vault/refs/',
        '/home/user/vault/projects/rust.md',
        '/home/user/vault/refs/projects/rust.md',
      }
      assert.equals('projects/rust', lib._shorten_item(item, paths, items, { cwd = '/home/user/vault' }))
    end)

    it('does not shorten all the way to an empty string when the item matches an entry in path', function()
      local item = '/home/user/vault/refs'
      local paths = {
        '/home/user/vault',
        '/home/user/vault/projects',
        '/home/user/vault/refs',
      }
      local items = {
        '/home/user/vault/refs/',
        '/home/user/vault/projects/rust.md',
        '/home/user/vault/refs/rust.md',
      }
      assert.equals('refs', lib._shorten_item(item, paths, items))
    end)
  end)

  describe('._find_completion_items', function()
    local suffixesadd

    before_each(function()
      suffixesadd = vim.o.suffixesadd
      vim.o.suffixesadd = '.md'
    end)

    after_each(function()
      vim.o.suffixesadd = suffixesadd
    end)

    it('returns items relative to the first matching entry in &path', function()
      local paths = {
        '/home/user/vault',
        '/home/user/vault/projects',
        '/home/user/vault/refs',
      }
      local globpath = function()
        return {
          '/home/user/vault/refs',
          '/home/user/vault/projects/rust.md',
          '/home/user/vault/refs/rust.md',
        }
      end
      local opts = { paths = paths, globpath = globpath }

      assert.same({
        {
          label = 'refs',
          path = '/home/user/vault/refs'
        },
        {
          label = 'projects/rust',
          path = '/home/user/vault/projects/rust.md',
        },
        {
          label = 'refs/rust',
          path = '/home/user/vault/refs/rust.md',
        }
      }, lib._find_completion_items('r', opts))
    end)
  end)

  local function build_mock_fs()
  end

  describe('.resolve', function()
    local mock_io = {
      open = function(p)
        if p == 'some/path.md' then
          return {
            read = function()
              return [[
# Test Markdown Content
`amazing`
]]
            end,
            close = function() end
          }
        end

        return nil
      end,
    }

    it('appends markdown previews', function()
      local completion_item = {
        label = 'some/label',
        path = 'some/path.md'
      }
      local was_called = false
      local callback = function(updated_item)
        assert.same({
          label = 'some/label',
          path = 'some/path.md',
          documentation = {
            kind = 'markdown',
            value = [[
# Test Markdown Content
`amazing`
]]
          }
        }, updated_item, 'resolve updated the completion item')
        was_called = true
      end

      ---@diagnostic disable-next-line: param-type-mismatch
      lib.resolve(nil, completion_item, callback, { io = mock_io })
      assert.equals(true, was_called, 'resolve invoked the callback')
    end)

    it('does nothing if it cannot open the completion file', function()
      local completion_item = {
        label = 'some/label',
        path = 'some/missing/path.md'
      }
      local was_called = false
      local callback = function(updated_item)
        assert.same({
          label = 'some/label',
          path = 'some/missing/path.md',
        }, updated_item, 'updated_item')
        was_called = true
      end

      ---@diagnostic disable-next-line: param-type-mismatch
      lib.resolve(nil, completion_item, callback, { io = mock_io })
      assert.equals(true, was_called, 'resolve invoked the callback (invalid path)')

      completion_item = {
        label = 'some/label',
      }
      was_called = false
      callback = function(updated_item)
        assert.same({
          label = 'some/label',
        }, updated_item, 'updated_item')
        was_called = true
      end

      ---@diagnostic disable-next-line: param-type-mismatch
      lib.resolve(nil, completion_item, callback, { io = mock_io })
      assert.equals(true, was_called, 'resolve invoked the callback (no path)')
    end)
  end)
end)
