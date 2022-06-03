if _VERSION == 'Lua 5.1' or _VERSION == 'Lua 5.2' then
	error('lpeg.vim needs Lua 5.3 or newer')
	return nil
end

-- Remove current directory: this will just cause problems.
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

local os       = require('os')
local lib      = dofile(vim.eval('g:lpeg_path') .. '/lua/lib.lua')
local vimlib   = dofile(vim.eval('g:lpeg_path') .. '/lua/vimlib.lua')
local ftdetect = dofile(vim.eval('g:lpeg_path') .. '/lua/filetype.lua')
local lexer    = dofile(vim.eval('g:lpeg_path') .. '/lua/lexer.lua')

-- Set the package path to our plugin directory (and *only* this directory).
-- This allows lexers to just use "require('lexer')" without a lot of fanfare.
--
-- There may be a better way of doing this. I'm kinda new to Lua and don't
-- really know what I'm doing 🙃
package.path = string.format('%s/lua/?.lua;%s/lexer/?.lua',
	vim.eval('g:lpeg_path'),
	vim.eval('g:lpeg_path'))

LPEG = {}

local timers = {}
function LPEG.times()
	print(table.concat(timers, '\n'))
end

-- Bufnr → syntax mapping.
local syntaxes = {}

-- Start parsing this file. This disables the standard Vim syntax highlights,
-- parses the entire buffer, and sets up autocmds to process edits.
--
-- TODO: allow passing an explicit filetype:
--   :LPeg python
function LPEG.Start()
	local name, filetype = ftdetect.Detect()
	if name == nil then
		return
	end

	local syntax = nil

	-- TODO: should probably move this to lexer.load.
	for path in string.gmatch(vim.eval('&runtimepath'), "[^,]+") do
		local path = path .. '/lexer/' .. name .. '.lua'
		local f = io.open(path, 'r')
		if f ~= nil then
			io.close(f)
			syntax = lexer.load(path)
			--vim.command('b:lpeg_syntax = "' .. path .. '"')
			vim.command('b:lpeg_syntax = 1')
			break
		end
	end
	if syntax == nil then
		if show_error then
			error('no lexer for filetype ' .. name)
		end
		return
	end

	LPEG.define_types(syntax)
	vim.command('set syntax=')
	syntaxes[vim.buffer().number] = syntax
	LPEG.apply(vim.eval('exists("g:lpeg_debug")') ~= 0)

	for _, cmd in pairs(filetype.cmd or {}) do
		vim.command(cmd)
	end
end

-- prefix the names with lpeg so it won't conflict with any other plugin or
-- whatnot.
function LPEG.prop_name(p)
	return 'lpeg_' .. p
end

-- Convert a custom style to a Vim highlight.
--
-- Unsupported:
--
--    font:        Font name.
--    size:        Font size.
--    weight:      Weight or boldness of a font, between 1 and 999.
--    eolfilled:   Background color extends to the end of the line.
--    case:        Font case, 'u' for upper, 'l' for lower, and 'm' for normal.
--    visible:     Text is visible.
--    changeable:  Text is changeable instead of read-only.
local function define_extra(name, style)
	-- in 0xBBGGRR or "#RRGGBB" format.
	-- TODO: need to translate colour names, set ctermfg, etc.
	local color = function(c, bg)
		if bg then return {guibg = c}
		else       return {guifg = c}
		end
	end

	local hl = vimlib.ls_hl()
	local r = {}
	for s in string.gmatch(style, '[^,]+') do
		if s == 'underlined' then
			lib.extend(r, {term = 'underline', cterm = 'underline', gui = 'underline'})
		elseif s == 'italics' then
			lib.extend(r, {term = 'italic', cterm = 'italic', gui = 'italic'})
		elseif s == 'bold' then
			lib.extend(r, {term = 'bold', cterm = 'bold',  gui = 'bold'})
		elseif s:sub(1, 5) == 'fore:' then
			lib.extend(r, color(s:sub(6), false))
		elseif s:sub(1, 5) == 'back:' then
			lib.extend(r, color(s:sub(6), true))
		elseif s:sub(1, 5) == 'link:' then
			local link_to = hl[s:sub(6)]
			lib.extend(r, link_to)

			-- Vim doesn't allow both linking to another group and overriding one
			-- attribute, so we just copy all of them.

			-- local id = vim.fn.synIDtrans(vim.fn.hlID(s:sub(6)))
			-- for _, mode in pairs({'gui', 'cterm', 'term'}) do
			-- 	-- TODO: 'font', 'sp', 'ul',
			-- 	for _, col in pairs({'fg', 'bg'}) do
			-- 		local cp = vim.call('synIDattr', id, tostring(a), mode)
			-- 		-- local cp = vim.fn.synIDattr(id, a, mode)
			-- 		if cp ~= 0 then
			-- 			print("CP", cp)
			-- 			r[mode .. col] = cp
			-- 		end
			-- 	end

			-- 	for _, a in pairs({'bold', 'italic', 'reverse', 'inverse', 'strike',
			-- 					   'underline', 'undercurl', 'standout'}) do
			-- 		if vim.fn.synIDattr(id, a, mode) == 1 then
			-- 			r[mode] = (r[mode] or '') .. a
			-- 		end
			-- 	end
			-- end
			-- print('L', s:sub(6))
			-- lib.repr(r)
			-- print()
		end
	end

	local cmd = ''
	if lib.empty(r) then
		cmd = string.format('hi def link lpeg_%s Normal', name)
	else
		cmd = 'hi lpeg_' .. name
		for k, v in pairs(r) do
			cmd = cmd .. ' ' .. k .. '=' .. v
		end
	end
	vim.command(cmd)

	return 'lpeg_' .. name
end

-- Add the default hightlights from Scintillua that Vim doesn't have.
local function hi_default()
	local hi = {
		class    = {'guifg=red', ''},
		embedded = {'guifg=red', ''},
		regex    = {'guifg=red', ''},
		variable = {'guifg=red', ''},
	}
	for k, v in pairs(hi) do
		if vim.fn.highlight_exists(k) == 0 then
			vim.command(string.format('hi %s %s', k, v[1]))
		end
	end
end

-- Styles internal to Vis that we can ignore.
local internal_styles = {
	'calltip', 'folddisplaytext', 'linenumber', 'bracelight',
	'bracebad', 'controlchar', 'indentguide',
	'nothing'
	-- 'default', 
}

-- Define the prop_types.
--
-- TODO: _foldsymbols.
function LPEG.define_types(syntax)
	-- Make sure the defaults are defined.
	hi_default()

	local buf   = vim.buffer()
	local bufnr = vim.dict({bufnr=buf.number})
	for p, s in pairs(syntax._TOKENSTYLES) do
		for _, k in pairs(internal_styles) do
			if k == p then goto continue_define_types end
		end

		local prop_name = LPEG.prop_name(p)
		local hl = p
		if p == 'preprocessor' then
			hl = 'PreProc'
		end

		if p:sub(-10) == 'whitespace' then
			goto continue_define_types 
		end

		-- Not a Vim highlight, look it up as an extra style.
		if vim.fn.highlight_exists(hl) == 0 then
			local extra = syntax._EXTRASTYLES[hl]
			if extra then
				hl = define_extra(hl, extra)
				-- if not hl then
				-- 	hl = 'Normal'
				-- end
			else
				hl = 'Normal'
			end
		end

		if vim.fn.prop_type_get(prop_name, bufnr) then
			vim.fn.prop_type_delete(prop_name, bufnr)
		end
		vim.fn.prop_type_add(prop_name, vim.dict({
			bufnr     = buf.number,
			highlight = hl,
		}))

		::continue_define_types::
	end
end

local function print_debug(data, name, token_start, token_stop, start, stop)
	local text = data:sub(token_start, token_stop):gsub('\n', '↪'):gsub('\t', '↦')
	if utf8.len(text) > 30 then
		text = utf8.sub(text, 1, 15) .. '…' .. utf8.sub(text, -15, -1)
	end

	local byte = ''
	if token_start == token_stop then
		byte = string.format('%d', token_start)
	else
		byte = string.format('%d-%d', token_start, token_stop)
	end

	local pos = ''
	if start.line == stop.line then
		if token_start == token_stop then
			pos = string.format('%d:%d', start.line, start.col)
		else
			pos = string.format('%d:%d-%d', start.line, start.col, stop.col)
		end
	else
		pos = string.format('%d:%d-%d:%d', start.line, start.col, stop.line, stop.col)
	end

	return string.format('%-15s  %-12s  %-16s  │%s│', name, byte, pos, text)
end

-- Parse the file and apply hightlights.
function LPEG.apply(debug)
	local stime     = os.clock()
	local buf       = vim.buffer()
	local syntax    = syntaxes[buf.number]
	local start     = vimlib.line2byte('w0', false)
	local stop      = vimlib.line2byte('w$', true)
	local lex_start = math.max(1, start - 32768)
	lex_start       = vim.fn.line2byte(vim.fn.byte2line(lex_start)) -- Start of line
	local dbg       = {}
	local data      = table.concat(buf, '\n'):sub(lex_start, stop)

	local tokens, timedout = syntax:lex(data, 1, vim.eval('&redrawtime'))
	if timedout then
		error(string.format('times out after %dms', vim.eval('&redrawtime')))
		return
	end

	vim.fn.prop_clear(1, vim.fn.line('$'))

	local token_stop = lex_start + (tokens[#tokens] or 1) - 1
	for i = #tokens - 1, 1, -2 do
		local token_start = lex_start + (tokens[i-1] or 1) - 1
		if token_stop < start then
			break
		end

		local name  = tokens[i]
		local start = vimlib.byte2linecol(token_start)
		local stop  = vimlib.byte2linecol(token_stop)

		if debug then
			table.insert(dbg, print_debug(data, name, token_start, token_stop, start, stop))
		end

		-- Don't add textprops for whitespace for now. I can't really
		-- think of a good reason to have this.
		if name:sub(-10) == 'whitespace' then
			goto continue
		end

		-- This used to happen due to a bug; this should be solved now, but keep
		-- this in here anyway since something going wrong will spam you will
		-- errors upon errors that you can't quit. See the Vim issue mentioned
		-- earlier.
		if start.col < 0 or stop.col < 0 then
			goto continue
		end

		vim.fn.prop_add(start.line, start.col, vim.dict({
			end_lnum = stop.line,
			end_col  = stop.col + 1,
			type     = LPEG.prop_name(name),
		}))

		::continue::
			token_stop = token_start - 1
	end

	table.insert(timers, string.format('%6d - %-6d → % 6.2fms', start, stop, (os.clock() - stime) * 1000))
	if #timers > 50 then table.remove(timers, 1) end

	if debug then
		print(string.format('%-15s  %-12s  %-16s  %s', 'name', 'byte pos', 'line:col', 'text'))
		for i = #dbg, 1, -1 do
			print(dbg[i])
		end
	end
end
