-- Some general Lua stuff, as the Lua stdlib is rather bare-bones.

local M = {}

-- Get a table size.
-- TODO: appearantly you can also use a "metatable"? Need to look in to what
-- thye are in the first place 😅
function M.table_size(t)
  local n = 0
  for _ in pairs(t) do
	  n = n + 1
  end
  return n
end

-- Split a string.
function M.split(s, split)
	t = {}
	for s in string.gmatch(s, '[^' .. split .. ',]+') do
		table.insert(t, s)
	end
	return t
end


-- UTF-8 aware stringsub.
function utf8.sub(s, start, stop)
	if start < 0 then start = utf8.len(s) + start + 1 end
	if stop  < 0 then stop  = utf8.len(s) + stop  + 1 end
    return string.sub(s,
		utf8.offset(s, start),
		utf8.offset(s, stop + 1) - 1)
end

-- Check if a table is empty.
function M.empty(tbl)
	for _, _ in pairs(tbl) do return false end
	return true
end

-- Extend a table. Not nested.
function M.extend(tbl, ...)
	if type(tbl) ~= 'table' then
		error(string.format('tbl is not a table but a %s', type(tbl)))
	end

	for i, t in pairs({...}) do
		if type(t) ~= 'table' then
			error(string.format('argument %d is not a table but a %s', i, type(t)))
		end
		for k, v in pairs(t) do
			tbl[k] = v
		end
	end
	return tbl
end

-- Print table as string.
function M.repr(...)
    local pr = {}
    for _, l in pairs({...}) do
        if type(l) == 'table' then
            local s = {}
            for k, v in pairs(l) do
				local fmt = '%q'
				if     type(v) == 'table'    then v = M.repr(v); fmt = '%s'
				elseif type(v) == 'function' then v = 'function'
				elseif type(v) == 'userdata' then v = 'userdata'
				end
                table.insert(s, string.format('%s=' .. fmt, k, v))
            end
            table.insert(pr, '{' .. table.concat(s, ', ') .. '}')
        else
            table.insert(pr, string.format("%q", l))
        end
    end
    return table.concat(pr, ' ')
end

return M
