if _VERSION == 'Lua 5.2' or _VERSION == 'Lua 5.1' then
	error('lpeg.vim needs Lua 5.3 or newer')
	return nil
end

-- Remove current directory; this will just cause problems.
package.path = package.path:gsub('./?.lua;', '')

-- Don't spam with huge errors; all of the runtimepath is added to package.path,
-- and it's pages upon pages of errors if you have a bunch of plugins. Plus, you
-- can't actualy stop this right now: https://github.com/vim/vim/issues/8649
local ok, _ = xpcall(require, function(err)
	print('lpeg.vim: ' .. err:sub(0, err:find('\n') - 2))
end, 'lpeg')
if not ok then
	return nil
end

local lpeg     = require('lpeg')
local os       = require('os')
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

local timeout = vim.eval('get(g:, "lpeg_timeout", 4)')


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
	LPEG.apply(syntax, vim.eval('exists("g:lpeg_debug")') ~= 0, 1, vim.fn.line('$'))
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
function LPEG.apply(syntax, debug, first_line, last_line)
	if syntax == nil then
		syntax = tmp_global_syntax  -- TODO: hack
	end

	local start  = os.clock()
	local buf    = vim.buffer()
	local bufnr  = vim.dict({bufnr = buf.number})
	--local data   = table.concat({table.unpack(buf, first_line, last_line)}, '\n')
	local data   = table.concat(vim.fn.getline(first_line, last_line), '\n')

	local tokens, timedout = syntax:lex(data, 1, timeout)
	if timedout then
		error(string.format('times out after %d seconds', timeout))
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

		local start_line = vim.fn.byte2line(token_start)
		local end_line   = vim.fn.byte2line(token_start + len)

		local start_col  = token_start - vim.fn.line2byte(start_line) + 1
		local end_col    = start_col + len + 1

		-- start_line = start_line + first_line - 1
		-- end_line   = end_line + first_line - 1

		if start_line ~= end_line then
			end_col = vim.fn.line2byte(end_line) - token_start + 1
		end

		if debug then
			local name  = tokens[i]
			local style = syntax._TOKENSTYLES[name]
			local text  = data:sub(token_start, token_start + len - 1):gsub('\n', '↪'):gsub('\t', '↦')
			if #text > 30 then
				text = text:sub(1, 15) .. '…' .. text:sub(-15, -1)
			end

			-- identifier      (6)    [12879]     399:14 - 399:21     |Stdout|
			-- operator        (1)    [12885]     399:20 - 399:22     |)|
			-- whitespace      (2)    [12886]     399:21 - 400:27702  |↪↦|
			-- keyword         (6)    [12888]  400:-27698 - 400:-27691  |return|
			-- whitespace      (1)    [12894]  400:-27692 - 400:-27690  | |
			print(string.format('%-15s %-5s  %-8s %9s - %-9s  |%s|',
				name, 
				string.format('(%d)', len),
				string.format('[%d]', token_start),
				string.format('%d:%d', start_line, start_col),
				string.format('%d:%d', end_line, end_col),
				text
			))
		end

		if start_col < 0 or end_col < 0 then -- TODO: this is a bug
			goto continue
		end
		if len == 0 then -- TODO: needed?
			goto continue
		end

		-- if entire_file or (start_line >= first_line and start_line <= last_line) then
		-- if start_line <= first_line and start_line >= last_line then
		-- 	goto continue
		-- end

		local name = tokens[i]
		local style = syntax._TOKENSTYLES[name]

		-- Don't add textprops for whitespace for now. I can't really
		-- think of a good reason to have this.
		if name == 'whitespace' then
			goto continue
		end

		vim.fn.prop_add(start_line, start_col, vim.dict({
			end_lnum = end_line,
			end_col  = end_col,
			type     = LPEG.prop_name(name),
		}))

		::continue::
	end

	table.insert(timers, string.format('apply %4d-%-4d → %.2fms', first_line, last_line, (os.clock() - start) * 1000))
end
