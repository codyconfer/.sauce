ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}| %{$reset_color%}%{$fg[green]%} "
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[yellow]%} ⚡"
ZSH_THEME_GIT_PROMPT_CLEAN=""

PROMPT='
%{$fg[blue]%}  %{$fg[cyan]%} %t%{$fg[yellow]%} | %{$fg[blue]%}  %{$fg[cyan]%}%n%{$fg[yellow]%} | %{$fg[blue]%}󰌢  %{$fg[cyan]%}%m%{$reset_color%}
%{$fg[blue]%}  %{$fg[cyan]%}  %1~%{$reset_color%} $(git_prompt_info)%{$fg[red]%}⛧ %{$fg[blue]%} %{$reset_color%} '
