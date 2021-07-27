-- Remove current directory; this will just cause problems.
package.path = package.path:gsub('./?.lua;', '')

local os     = require('os')
local lpeg   = require('lpeg')

local lexer    = dofile(vim.eval('g:lpeg_path') .. '/lexer.lua')
local ftdetect = dofile(vim.eval('g:lpeg_path') .. '/filetype.lua')

-- Set the package path to our plugin directory (and *only* this directory).
-- This allows lexers to just use "require('lexer')" without a lot of fanfare.
--
-- There may be a better way of doing this. I'm kinda new to Lua and don't
-- really know what I'm doing 🙃
--
-- TODO: this actually breaks embedding lexers, like markdown.lua embedding
-- html.lua – need to tweak lexer.lua to use runtimepath.
package.path = vim.eval('g:lpeg_path') .. '/?.lua'

local timeout = vim.eval('get(g:, "lpeg_timeout", 3)')


local tmp_global_syntax = nil  -- TODO
LPEG = {}

local timers = {}
function LPEG.times()
	print(table.concat(timers, '\n'))
end

-- Start parsing this file. This disables the standard Vim syntax highlights,
-- parses the entire buffer, and sets up autocmds to process edits.
--
-- TODO: allow passing an explicit filetype:
--   :Lpeg python
function LPEG.Start()
	local name, filetype = Detect()
	if name == nil then
		return
	end

	local syntax = nil
	for path in string.gmatch(vim.eval('&runtimepath'), "[^,]+") do
		local path = path .. '/lexer/' .. name .. '.lua'
		local f = io.open(path, 'r')
		if f ~= nil then
			io.close(f)
			syntax = lexer.load(path)
			vim.command('b:lpeg_syntax = "' .. path .. '"')
			break
		end
	end
	if syntax == nil then
		error('no lexer for filetype ' .. name)
		return
	end

	LPEG.define_types(syntax)
	vim.command('set syntax=')
	LPEG.apply(syntax, true)
	tmp_global_syntax = syntax

	for _, cmd in pairs(filetype.cmd or {}) do
		vim.command(cmd)
	end
end

-- prefix the names with lpeg so it won't conflict with any other plugin or
-- whatnot.
function LPEG.prop_name(p)
	return 'lpeg-' .. p
end

-- Define the prop_types.
--
-- TODO: _tokenstyles and _foldsymbols.
function LPEG.define_types(syntax)
	local buf   = vim.buffer()
	local bufnr = vim.dict({bufnr=buf.number})
	local props = vim.fn.prop_type_list()

	for p, _ in pairs(syntax._TOKENSTYLES) do
		local prop_name = LPEG.prop_name(p)
		local hl        = p
		if vim.fn.highlight_exists(hl) == 0 then
			hl = 'Normal'
		end

		if vim.fn.prop_type_get(prop_name, bufnr) then
			vim.fn.prop_type_delete(prop_name, bufnr)
		end
		vim.fn.prop_type_add(prop_name, vim.dict({
			bufnr=     buf.number,
			highlight= hl,
		}))
	end
end

-- Parse the file and apply hightlights.
--
-- If entire_file is true the entire file will be parsed and highlighted. If
-- it's false then only the visible area will be.
function LPEG.apply(syntax, entire_file, debug)
	if syntax == nil then
		syntax = tmp_global_syntax
	end

	local first_line   = vim.fn.line('w0')
	local last_line    = vim.fn.line('w$')
	local start        = os.clock()
	local buf          = vim.buffer()
	local bufnr        = vim.dict({bufnr = buf.number})
	local token_styles = syntax._TOKENSTYLES
	local data         = ''
	if entire_file then
		data = table.concat(buf, '\n')
	else
		data = table.concat({table.unpack(buf, first_line, last_line)}, '\n')
	end

	local tokens, timedout = syntax:lex(data, 1, timeout)
	if timedout then
		return
	end

	vim.fn.prop_clear(first_line, last_line)

	-- vis loops in reverse, why?
	-- for i = #tokens - 1, 1, -2 do
	for i = 1, #tokens, 2 do
		local token_start = (tokens[i-1] or 1)
		local len = 0
		if i < #tokens then
			len = tokens[i+1] - token_start
		end


		local start_line  = vim.fn.byte2line(token_start)
		local start_col   = token_start - vim.fn.line2byte(start_line) + 1
		local end_line    = vim.fn.byte2line(token_start + len)
		local end_col     = len + 1
		if start_line ~= end_line then
			end_col = vim.fn.line2byte(end_line) - token_start + 1
		end

		if entire_file or (start_line >= first_line and start_line <= last_line) then
			local name = tokens[i]
			local style = token_styles[name]

			if len > 0 then
				if debug then
					print(string.format('%-15s %-4s %9s - %-9s', name, 
						string.format('(%d)', len),
						string.format('%d:%d', start_line, start_col),
						string.format('%d:%d', end_line, end_col)))
				end

				vim.fn.prop_add(start_line, start_col, vim.dict({
					end_lnum = end_line,
					end_col  = end_col,
					type     = LPEG.prop_name(name),
				}))
			end
		end
	end

	if entire_file then
		table.insert(timers, string.format('apply file      → %.2fms', (os.clock() - start) * 1000))
	else
		table.insert(timers, string.format('apply %4d-%-4d → %.2fms', first_line, last_line, (os.clock() - start) * 1000))
	end
end
