"  This program is free software; you can redistribute it and/or modify
"  it under the terms of the GNU General Public License as published by
"  the Free Software Foundation; either version 2 of the License, or
"  (at your option) any later version.
"
"  This program is distributed in the hope that it will be useful,
"  but WITHOUT ANY WARRANTY; without even the implied warranty of
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"  GNU General Public License for more details.
"
"  A copy of the GNU General Public License is available at
"  http://www.r-project.org/Licenses/

"==========================================================================
" ftplugin for RBrowser files (created by the Vim-R-plugin)
"
" Author: Jakson Alves de Aquino <jalvesaq@gmail.com>
"          
"==========================================================================

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
    finish
endif

let g:rplugin_upobcnt = 0

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Source scripts common to R, Rnoweb, Rhelp and rdoc files:
runtime r-plugin/common_global.vim

" Some buffer variables common to R, Rnoweb, Rhelp and rdoc file need be
" defined after the global ones:
runtime r-plugin/common_buffer.vim

setlocal noswapfile
setlocal buftype=nofile
setlocal nowrap
setlocal iskeyword=@,48-57,_,.

if !exists("g:rplugin_hasmenu")
    let g:rplugin_hasmenu = 0
endif

" Popup menu
if !exists("g:rplugin_hasbrowsermenu")
    let g:rplugin_hasbrowsermenu = 0
endif

" Current view of the object browser: .GlobalEnv X loaded libraries
let g:rplugin_curview = "GlobalEnv"


function! UpdateOB(what)
    if a:what == "both"
        let wht = g:rplugin_curview
    else
        let wht = a:what
    endif
    if g:rplugin_curview != wht
        return "curview != what"
    endif
    if g:rplugin_upobcnt
        echoerr "OB called twice"
        return "OB called twice"
    endif
    let g:rplugin_upobcnt = 1

    let g:rplugin_switchedbuf = 0
    if $TMUX_PANE == ""
        redir => s:bufl
        silent buffers
        redir END
        if s:bufl !~ "Object_Browser"
            let g:rplugin_upobcnt = 0
            return "Object_Browser not listed"
        endif
        if exists("g:rplugin_curbuf") && g:rplugin_curbuf != "Object_Browser"
            let savesb = &switchbuf
            set switchbuf=useopen,usetab
            sil noautocmd sb Object_Browser
            let g:rplugin_switchedbuf = 1
        endif
    endif

    setlocal modifiable
    let curline = line(".")
    let curcol = col(".")
    if !exists("curline")
        let curline = 3
    endif
    if !exists("curcol")
        let curcol = 1
    endif
    let save_unnamed_reg = @@
    sil normal! ggdG
    let @@ = save_unnamed_reg 
    if wht == "GlobalEnv"
        let fcntt = readfile($VIMRPLUGIN_TMPDIR . g:rplugin_globenv_f)
    else
        let fcntt = readfile($VIMRPLUGIN_TMPDIR . g:rplugin_liblist_f)
    endif
    call setline(1, fcntt)
    call cursor(curline, curcol)
    if bufname("%") =~ "Object_Browser" || b:rplugin_extern_ob
        setlocal nomodifiable
    endif
    redraw
    if g:rplugin_switchedbuf
        exe "sil noautocmd sb " . g:rplugin_curbuf
        exe "set switchbuf=" . savesb
    endif
    let g:rplugin_upobcnt = 0
    return "End of UpdateOB()"
endfunction

function! RBrowserDoubleClick()
    " Toggle view: Objects in the workspace X List of libraries
    if line(".") == 1
        if g:rplugin_curview == "libraries"
            let g:rplugin_curview = "GlobalEnv"
            call UpdateOB("GlobalEnv")
        else
            let g:rplugin_curview = "libraries"
            call UpdateOB("libraries")
        endif
        return
    endif

    " Toggle state of list or data.frame: open X closed
    let key = RBrowserGetName(0, 1)
    if g:rplugin_curview == "GlobalEnv"
        exe 'Py SendToVimCom("' . "\005" . key . '")'
        if g:rplugin_lastrpl == "R is busy."
            call RWarningMsg("R is busy.")
        endif
    else
        let key = substitute(key, '`', '', "g") 
        if key !~ "^package:"
            let key = "package:" . RBGetPkgName() . '-' . key
        endif
        exe 'Py SendToVimCom("' . "\005" . key . '")'
        if g:rplugin_lastrpl == "R is busy."
            call RWarningMsg("R is busy.")
        endif
    endif
    if v:servername == "" || has("win32") || has("win64")
        sleep 50m " R needs some time to write the file.
        call UpdateOB("both")
    endif
endfunction

function! RBrowserRightClick()
    if line(".") == 1
        return
    endif

    let key = RBrowserGetName(1, 0)
    if key == ""
        return
    endif

    let line = getline(".")
    if line =~ "^   ##"
        return
    endif
    let isfunction = 0
    if line =~ "(#.*\t"
        let isfunction = 1
    endif

    if g:rplugin_hasbrowsermenu == 1
        aunmenu ]RBrowser
    endif
    let key = substitute(key, '\.', '\\.', "g")
    let key = substitute(key, ' ', '\\ ', "g")

    exe 'amenu ]RBrowser.summary('. key . ') :call RAction("summary")<CR>'
    exe 'amenu ]RBrowser.str('. key . ') :call RAction("str")<CR>'
    exe 'amenu ]RBrowser.names('. key . ') :call RAction("names")<CR>'
    exe 'amenu ]RBrowser.plot('. key . ') :call RAction("plot")<CR>'
    exe 'amenu ]RBrowser.print(' . key . ') :call RAction("print")<CR>'
    amenu ]RBrowser.-sep01- <nul>
    exe 'amenu ]RBrowser.example('. key . ') :call RAction("example")<CR>'
    exe 'amenu ]RBrowser.help('. key . ') :call RAction("help")<CR>'
    if isfunction
        exe 'amenu ]RBrowser.args('. key . ') :call RAction("args")<CR>'
    endif
    popup ]RBrowser
    let g:rplugin_hasbrowsermenu = 1
endfunction

function! RBGetPkgName()
    let lnum = line(".")
    while lnum > 0
        let line = getline(lnum)
        if line =~ '.*##[0-9a-zA-Z\.]*\t'
            let line = substitute(line, '.*##\(.*\)\t', '\1', "")
            return line
        endif
        let lnum -= 1
    endwhile
    return ""
endfunction

function! RBrowserFindParent(word, curline, curpos)
    let curline = a:curline
    let curpos = a:curpos
    while curline > 1 && curpos >= a:curpos
        let curline -= 1
        let line = substitute(getline(curline), "	.*", "", "")
        let curpos = stridx(line, '[#')
        if curpos == -1
            let curpos = stridx(line, '<#')
            if curpos == -1
                let curpos = a:curpos
            endif
        endif
    endwhile

    if g:rplugin_curview == "GlobalEnv"
        let spacelimit = 3
    else
        if s:isutf8
            let spacelimit = 10
        else
            let spacelimit = 6
        endif
    endif
    if curline > 1
        let line = substitute(line, '^.\{-}\(.\)#', '\1#', "")
        let line = substitute(line, '^ *', '', "")
        if line =~ " " || line =~ '^.#[0-9]'
            let line = substitute(line, '\(.\)#\(.*\)$', '\1#`\2`', "")
        endif
        if line =~ '<#'
            let word = substitute(line, '.*<#', "", "") . '@' . a:word
        else
            let word = substitute(line, '.*\[#', "", "") . '$' . a:word
        endif
        if curpos != spacelimit
            let word = RBrowserFindParent(word, line("."), curpos)
        endif
        return word
    else
        " Didn't find the parent: should never happen.
        let msg = "R-plugin Error: " . a:word . ":" . curline
        echoerr msg
    endif
    return ""
endfunction

function! RBrowserCleanTailTick(word, cleantail, cleantick)
    let nword = a:word
    if a:cleantick
        let nword = substitute(nword, "`", "", "g")
    endif
    if a:cleantail
        let nword = substitute(nword, '[\$@]$', '', '')
        let nword = substitute(nword, '[\$@]`$', '`', '')
    endif
    return nword
endfunction

function! RBrowserGetName(cleantail, cleantick)
    let line = getline(".")
    if line =~ "^$"
        return ""
    endif

    let curpos = stridx(line, "#")
    let word = substitute(line, '.\{-}\(.#\)\(.\{-}\)\t.*', '\2\1', '')
    let word = substitute(word, '\[#$', '$', '')
    let word = substitute(word, '<#$', '@', '')
    let word = substitute(word, '.#$', '', '')

    if word =~ ' ' || word =~ '^[0-9]'
        let word = '`' . word . '`'
    endif

    if (g:rplugin_curview == "GlobalEnv" && curpos == 4) || (g:rplugin_curview == "libraries" && curpos == 3)
        " top level object
        let word = substitute(word, '\$\[\[', '[[', "g")
        let word = RBrowserCleanTailTick(word, a:cleantail, a:cleantick)
        if g:rplugin_curview == "libraries"
            return "package:" . substitute(word, "#", "", "")
        else
            return word
        endif
    else
        if g:rplugin_curview == "libraries"
            if s:isutf8
                if curpos == 11
                    let word = RBrowserCleanTailTick(word, a:cleantail, a:cleantick)
                    let word = substitute(word, '\$\[\[', '[[', "g")
                    return word
                endif
            elseif curpos == 7
                let word = RBrowserCleanTailTick(word, a:cleantail, a:cleantick)
                let word = substitute(word, '\$\[\[', '[[', "g")
                return word
            endif
        endif
        if curpos > 4
            " Find the parent data.frame or list
            let word = RBrowserFindParent(word, line("."), curpos - 1)
            let word = RBrowserCleanTailTick(word, a:cleantail, a:cleantick)
            let word = substitute(word, '\$\[\[', '[[', "g")
            return word
        else
            " Wrong object name delimiter: should never happen.
            let msg = "R-plugin Error: (curpos = " . curpos . ") " . word
            echoerr msg
            return ""
        endif
    endif
endfunction

function! MakeRBrowserMenu()
    let g:rplugin_curbuf = bufname("%")
    if g:rplugin_hasmenu == 1
        return
    endif
    menutranslate clear
    call RControlMenu()
    call RBrowserMenu()
endfunction

function! ObBrBufUnload()
    if exists("g:rplugin_editor_sname")
        call system("tmux select-pane -t " . g:rplugin_vim_pane)
    endif
endfunction

function! SourceObjBrLines()
    exe "source " . g:rplugin_esc_tmpdir . "/objbrowserInit"
endfunction

nmap <buffer><silent> <CR> :call RBrowserDoubleClick()<CR>
nmap <buffer><silent> <2-LeftMouse> :call RBrowserDoubleClick()<CR>
nmap <buffer><silent> <RightMouse> :call RBrowserRightClick()<CR>

call RControlMaps()

setlocal winfixwidth
setlocal bufhidden=wipe

if has("gui_running")
    call RControlMenu()
    call RBrowserMenu()
endif

au BufEnter <buffer> stopinsert

if $TMUX_PANE == ""
    au BufUnload <buffer> Py SendToVimCom("\x08Stop updating info [OB BufUnload].")
else
    au BufUnload <buffer> call ObBrBufUnload()
    " Fix problems caused by some plugins
    if exists("g:loaded_surround")
        nunmap ds
    endif
    if exists("g:loaded_showmarks ")
        autocmd! ShowMarks
    endif
endif

let s:envstring = tolower($LC_MESSAGES . $LC_ALL . $LANG)
if s:envstring =~ "utf-8" || s:envstring =~ "utf8"
    let s:isutf8 = 1
else
    let s:isutf8 = 0
endif
unlet s:envstring

call setline(1, ".GlobalEnv | Libraries")

call RSourceOtherScripts()

let &cpo = s:cpo_save
unlet s:cpo_save

