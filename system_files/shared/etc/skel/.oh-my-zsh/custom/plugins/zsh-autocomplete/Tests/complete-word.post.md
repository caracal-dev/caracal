Setup:
```zsh
% source Tests/__init__.zsh
%
```

Default completion widget inserts first match.
```zsh
% compstate[old_list]=keep
% _lastcomp[nmatches]=2
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]}
1
%
```

`menu-` widgets should cycle between completions.
```zsh
% WIDGETSTYLE=menu-complete
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]} $+MENUSELECT $MENUMODE
menu:1 0
%
```

`menu-select` widgets should enter the menu.
```zsh
% WIDGETSTYLE=menu-select
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]} $+MENUSELECT $MENUMODE
menu:1 1
%
```

`menu-select` widgets with `search` in the name should start a full-text search.
```zsh
% WIDGET=incremental-history-search-forward
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]} $+MENUSELECT $MENUMODE
menu:1 1 search-forward
%
```

`reverse-menu-complete` widgets should select the last match.
```zsh
% WIDGETSTYLE=reverse-menu-complete
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]}
menu:0
% WIDGETSTYLE=
%
```

Widgets with `reverse` in the name should do so, too.
```zsh
% WIDGET=reverse-complete
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]}
0
% WIDGET=
%
```

Widgets can be configured to inset `unambiguous` instead.
```zsh
% zstyle ':autocomplete:*' insert-unambiguous yes
% compstate[old_list]=
% compstate[nmatches]=2
% compstate[unambiguous]=foo
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]} $+MENUSELECT $MENUMODE
unambiguous 0
%
```

Menu widgets should prefix `unambiguous` with `automenu-`.
```zsh
% WIDGETSTYLE=menu-select
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]} $+MENUSELECT $MENUMODE
automenu-unambiguous 0
% compstate[unambiguous]=
% WIDGETSTYLE=
%
```

Certain completions should be suffixed with a space.
```zsh
% zstyle ':autocomplete:*' add-space foo bar
% _comp_tags='foo bar'
% .autocomplete__complete-word__post
% print -r -- ${(q+)compstate[insert]}
'1 '
%
```
