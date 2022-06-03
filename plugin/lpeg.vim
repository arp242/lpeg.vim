vim9script

if exists('g:loaded_lpeg') | finish | endif
g:loaded_lpeg = 1

g:lpeg_path = expand('<sfile>:p:h:h')
exe 'luafile' g:lpeg_path .. '/lua/lpeg.lua'

command -nargs=* -complete=customlist,Complete Lpeg Cmd(<f-args>)

def Cmd(...splat: list<string>)
	var cmd  = 'start'
	var args = splat
	if len(splat) > 0
		cmd  = args[0]
		args = args[1 :]
	endif

	if cmd == 'times'
		lua print(LPEG.times())
	elseif cmd == 'parse'
		lua LPEG.apply(true)
	elseif cmd == 'start' || cmd == 'autostart'
		exe printf('lua LPEG.Start(%s)', cmd == 'start')
		if !exists('b:lpeg_syntax')
			return
		endif

		b:lpeg_last = [line('w0'), line('w$')]
		augroup lpeg.vim
			au!
			au TextChanged,TextChangedI <buffer> lua LPEG.apply(false)
			au SafeState                <buffer> SafeState()
		augroup end
	elseif cmd == 'stop'
		if !exists('b:lpeg_syntax')
			Error('Lpeg not enabled')
			return
		endif

		augroup lpeg.vim | au! | augroup end

		prop_clear(1, line('$'))
		var buf = {bufnr: bufnr('')}
		for p in prop_type_list(buf)
			if p[: 4] == 'lpeg-'
				prop_type_delete(p, buf)
			endif
		endfor

		&syntax = &filetype
		unlet b:lpeg_syntax
	else
		Error('unknown command: %s', cmd)
	endif
enddef

def Complete(lead: string, cmdlind: string, pos: number): list<string>
	return ['autostart', 'start', 'stop', 'times', 'parse']->sort()
		->filter((_, v) => strpart(v, 0, len(lead)) == lead)
enddef

def SafeState()
	var vis = [line('w0'), line('w$')]
	if vis != b:lpeg_last
		lua LPEG.apply(false)
	endif
	b:lpeg_last = vis
enddef

def Error(msg: string, ...args: list<string>)
	echohl ErrorMsg
	echo call('printf', ['lpeg.vim: ' .. msg] + args)
	echohl None
enddef


defcompile
