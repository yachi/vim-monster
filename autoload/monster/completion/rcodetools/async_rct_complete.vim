scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

call vital#of("monster").unload()
let s:Reunions = vital#of("monster").import("Reunions")

" 補完モードを終了するハック
function! s:exit_completion_mode()
" 	doautocmd CursorHoldI
" 	if !pumvisible()
" 		return ""
" 	endif
	execute "normal! \<C-g>\<ESC>"
	return ""
endfunction


" inoremap <silent> <Plug>(monster-exit-completion-mode) <C-r>=<SID>exit_completion_mode()<CR><Right>

inoremap <silent><expr> <Plug>(monster-exit-completion-mode) "\<C-r>=\<SID>exit_completion_mode()\<CR>" . (col(".") == 1 ? "" : "\<Right>")


function! monster#completion#rcodetools#async_rct_complete#complete(context)
	call monster#completion#rcodetools#async_rct_complete#cancel()
	if !executable("rct-complete")
		call monster#errmsg("No executable 'rct-complete' command.")
		call monster#errmsg("Please install 'gem install rcodetools'.")
		return []
	endif

	let tempfile = monster#make_tempfile(a:context.bufnr, "rb")
	let command = monster#completion#rcodetools#rct_complete#command(a:context, tempfile)
	let process = s:Reunions.process(command)
	let process.tempfile = tempfile
	let process.context = a:context
	function! process.then(output, result)
		call delete(self.tempfile)
		call monster#debug_log(
\			"[async_rct_complete.vm] rct-complete result : \n" . string(a:result) . "\n"
\		)

		if a:result.status != "success"
			echo "monster.vim - failed async completion"
			return
		endif
		call monster#cache#add(self.context, monster#completion#rcodetools#parse(a:output))
		echo "monster.vim - finish async completion"
		if monster#context#get_current().cache_keyword !=# self.context.cache_keyword
			return
		endif
		call monster#start_complete(0, self.context)
		call feedkeys("\<C-p>")
	endfunction

	call monster#debug_log(
\		"[async_rct_complete.vm] rct-complete command : " . command . "\n"
\	)

	let s:process = process

	call feedkeys("\<Plug>(monster-exit-completion-mode)")
	
	return []
endfunction


function! monster#completion#rcodetools#async_rct_complete#is_alive_process()
	return !(exists("s:process") && s:process.is_exit())
endfunction


function! monster#completion#rcodetools#async_rct_complete#cancel()
	if !exists("s:process")
		return
	endif
	echo "monster.vim - cancel async completion"
	call s:process.kill(1)
	unlet s:process
endfunction


function! monster#completion#rcodetools#async_rct_complete#test()
	let start_time = reltime()
	let context = monster#context#get_current()
	try
		call monster#completion#rcodetools#async_rct_complete#complete(context)
		call s:process.wait()
		let result = monster#cache#get(context)
		return { "context" : context, "result" : result }
	finally
		echom "Complete time " . reltimestr(reltime(start_time))
	endtry
endfunction



let s:count = 0
augroup monster-completion-rcodetools-async_rct_complete
	autocmd!
" 	autocmd CursorHoldI * echo s:count | let s:count += 1 | call feedkeys(mode() =~# '[iR]' ? "\<C-g>\<ESC>" : "g\<ESC>", 'n')
" 	autocmd CursorHoldI * echo s:count | let s:count += 1
	autocmd InsertCharPre,CursorHoldI * call s:Reunions.update_in_cursorhold(1)
" 	autocmd InsertCharPre * call feedkeys("\<Plug>(monster-exit-completion-mode-hoge)")
	autocmd InsertEnter,InsertLeave * call monster#completion#rcodetools#async_rct_complete#cancel()
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
