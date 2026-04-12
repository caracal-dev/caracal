setopt localoptions extendedglob clobber NO_aliases localloops pipefail NO_shortloops NO_unset
zmodload zsh/param/private
autoload -Uz zmathfunc && zmathfunc
builtin autoload -UWz $PWD/{Completions,Functions}/**/[_.]autocomplete(__|:)*~*.zwc(DN-.:P)
typeset -gA compstate=() _lastcomp=()
typeset -ga compargs=() comppostfuncs=() comptags=()
typeset -g WIDGET= WIDGETSTYLE= context= curcontext=
