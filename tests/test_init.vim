set rtp+=.
let &rtp= &rtp . ',' . expand('<sfile>:h')
runtime plugin/plenary.vim

nnoremap ,,x :luafile %<CR>
