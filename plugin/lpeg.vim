vim9script

g:lpeg_path = expand('<sfile>:p:h')
exe 'luafile' g:lpeg_path .. '/lpeg.lua'

def Error(msg: string, ...args: list<string>)
	echohl ErrorMsg
	echo call('printf', ['lpeg.vim: ' .. msg] + args)
	echohl None
enddef

def Cmd(...splat: list<string>)
	var cmd  = 'start'
	var args = splat
	if len(splat) > 0
		cmd  = args[0]
		args = args[1 :]
	endif

	if cmd == 'start'
		lua LPEG.Start()
		augroup lpeg.vim
			au!
			# We can optimize this a bit more, as apply() will just re-highlight the
			# entire buffer. Textobjects are "smart" and will move if the buffer
			# changes, so this really isn't needed.
			#
			# Overal, this seems "fast enough" for now.
			au TextChanged,TextChangedI  <buffer> lua LPEG.apply(nil, false, false)
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
	elseif cmd == 'times'
		lua print(LPEG.times())
	elseif cmd == 'parse'
		# var start = 1
		# var stop  = line('$')
		# if len(args) >= 1
		# 	start = args[1]->str2nr()
		# endif
		# if len(args) >= 2
		# 	stop = args[2]->str2nr()
		# endif
		# lua LPEG.dbg(start, stop)
		lua LPEG.apply(nil, false, true)
	endif
enddef

def Complete(lead: string, cmdlind: string, pos: number): list<string>
	return ['autostart', 'start', 'stop', 'times', 'parse']->sort()
		->filter((_, v) => strpart(v, 0, len(lead)) == lead)
enddef

command -nargs=? -complete=customlist,Complete Lpeg Cmd(<f-args>)


defcompile
