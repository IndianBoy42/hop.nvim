if !has('nvim')
  echohl Error
  echom 'This plugin only works with Neovim'
  echohl clear
  finish
endif

" The jump-to-word command.
command! HopWord lua require'hop'.hint_words()
command! HopWordBC lua require'hop'.hint_words({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopWordAC lua require'hop'.hint_words({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-pattern command.
command! HopPattern lua require'hop'.hint_patterns()
command! HopPatternBC lua require'hop'.hint_patterns({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopPatternAC lua require'hop'.hint_patterns({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-char-1 command.
command! HopChar1 lua require'hop'.hint_char1()
command! HopChar1BC lua require'hop'.hint_char1({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopChar1AC lua require'hop'.hint_char1({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-char-2 command.
command! HopChar2 lua require'hop'.hint_char2()
command! HopChar2BC lua require'hop'.hint_char2({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopChar2AC lua require'hop'.hint_char2({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-line (vertical) command.
command! HopVertical lua require'hop'.hint_lines_vertical(nil)
command! HopVerticalBC lua require'hop'.hint_lines_vertical({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopVerticalAC lua require'hop'.hint_lines_vertical({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-line command.
command! HopLine lua require'hop'.hint_lines()
command! HopLineBC lua require'hop'.hint_lines({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopLineAC lua require'hop'.hint_lines({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-line command.
command! HopLineStart   lua require'hop'.hint_lines_skip_whitespace()
command! HopLineStartBC lua require'hop'.hint_lines_skip_whitespace({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })
command! HopLineStartAC lua require'hop'.hint_lines_skip_whitespace({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })

" The jump-to-char-1 command constrained to current line
command! HopChar1Line lua require'hop'.hint_char1_line()
command! HopChar1LineAC lua require'hop'.hint_char1_line({ direction = require'hop.constants'.HintDirection.AFTER_CURSOR })
command! HopChar1LineBC lua require'hop'.hint_char1_line({ direction = require'hop.constants'.HintDirection.BEFORE_CURSOR })

command! HopLocals lua require'hop'.hint_locals()
command! HopDefinitions lua require'hop'.hint_definitions()
command! HopReferences lua require'hop'.hint_references()
command! HopScopes lua require'hop'.hint_scopes()
command! HopUsages lua require'hop'.hint_references(nil, '<cword>')
command! HopTextobjects lua require'hop'.hint_textobjects()
command! HopFunctions lua require'hop'.hint_textobjects({ query = 'function' })

command! HopCword lua require'hop'.hint_cword()
command! HopCWORD lua require'hop'.hint_cWORD()
