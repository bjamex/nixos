-- Fixed IDE layout: the Snacks file explorer as a left sidebar (the same one
-- <leader>e uses) plus a bottom-split terminal, opened automatically on every
-- launch — with no file, a directory, or a specific file (`nvim foo.lua`).
-- Only genuinely transient invocations are skipped: git commit/rebase message
-- editing, diff mode (`nvim -d`), and stdin/pager use, where a full IDE layout
-- would just be in the way.
--
-- The autocmds are registered here at module scope rather than through a plugin
-- spec's `init`: lazy.nvim requires each plugins/*.lua file during startup (well
-- before VimEnter), so this runs early enough, and it avoids colliding with the
-- `init` that theme.lua already attaches to LazyVim/LazyVim (lazy keeps only one
-- init per plugin, so a second one would be silently dropped). The file still
-- returns a spec table so lazy is happy — just an empty one.

-- nvim invoked as a pager (`… | nvim -`) triggers StdinReadPre; flag it so
-- VimEnter can bail out of building the layout.
vim.api.nvim_create_autocmd("StdinReadPre", {
  once = true,
  callback = function()
    vim.g._layout_from_stdin = true
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    -- Transient edits get a plain window, no sidebar/terminal.
    if vim.g._layout_from_stdin or vim.o.diff then
      return
    end
    local skip_ft = {
      gitcommit = true,
      gitrebase = true,
      hgcommit = true,
    }
    if skip_ft[vim.bo.filetype] then
      return
    end

    -- Defer so Snacks is fully initialised first.
    vim.schedule(function()
      local editor = vim.api.nvim_get_current_win()

      -- Bottom terminal split, ~25% tall.
      pcall(function()
        Snacks.terminal.open(nil, { win = { position = "bottom", height = 0.25 } })
      end)

      -- Left sidebar file tree (Snacks explorer). A directory launch already
      -- opens it, so only open it when it isn't up yet.
      local explorer_open = false
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local ft = vim.api.nvim_get_option_value("filetype", { buf = vim.api.nvim_win_get_buf(w) })
        if ft:match("^snacks_picker") then
          explorer_open = true
          break
        end
      end
      if not explorer_open then
        pcall(function()
          Snacks.explorer.open()
        end)
      end

      -- Return focus to the editor window.
      if vim.api.nvim_win_is_valid(editor) then
        vim.api.nvim_set_current_win(editor)
      end
    end)
  end,
})

return {}
