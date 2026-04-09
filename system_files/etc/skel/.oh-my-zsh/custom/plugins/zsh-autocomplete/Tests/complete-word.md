Setup:
```zsh
% source Tests/__init__.zsh
% autocomplete:_main_complete:new() {}
%
```

`menu-` widgets should not keep a partial list.
```zsh
% compstate[old_list]=yes
% typeset -g _autocomplete__partial_list
% WIDGETSTYLE=menu-complete
% _autocomplete__should_insert_unambiguous() { false }
% .autocomplete__complete-word__completion-widget
% print -r -- $compstate[old_list]

%
```

You cannot insert unambiguous using only an old list.
```zsh
% compstate[old_list]=yes
% unset _autocomplete__partial_list
% _lastcomp[unambiguous]=foo
% _autocomplete__should_insert_unambiguous() { true }
% .autocomplete__complete-word__completion-widget
% print -r -- $compstate[old_list]

%
```
