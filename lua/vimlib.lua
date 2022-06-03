local M = {}

local lib = dofile(vim.eval('g:lpeg_path') .. '/lua/lib.lua')

-- List all highlights as a table:
--
--   {
--     cssPseudoClassFn  = {},  -- Cleared
--     pythonConditional = {ctermfg="130", gui="bold", term="bold", guifg="#af5f00"},
--   }
--
-- Links are resolved, for example pythonConditional links to Conditional which
-- links to Statement: the highlights of Statement are shown.
function M.ls_hl()
	local hi = {}
	for _, h in pairs(lib.split(vim.fn.execute('highlight'), '\n')) do
		h = lib.split(h, '%s')
		hi[h[1]] = {table.unpack(h, 3, #h)}
	end

	local t = {}
	for name, h in pairs(hi) do
		while h[1] == 'links' do
			h = hi[h[3]]
		end
		t[name] = {}

		if h[1] == 'cleared' then
			goto ls_hl_continue
		end

		for _, prop in pairs(h) do
			prop = lib.split(prop, '=')
			t[name][prop[1]] = prop[2]
		end

		::ls_hl_continue::
	end
	return t
end

-- line2byte on line expression (i.e. 5, '.', '$', etc).
--
-- If at_end is true it gets the byte of the last column, rather than the first.
function M.line2byte(line, at_end)
	local b = vim.fn.line2byte(vim.fn.line(line))
	if at_end then
		b = b + #vim.fn.getline(line)
	end
	return b
end

-- Get line and column for a byte position.
function M.byte2linecol(byte)
	local line = vim.fn.byte2line(byte)
	local col  = byte - vim.fn.line2byte(line) + 1
	return {line = line, col = col}
end

return M
