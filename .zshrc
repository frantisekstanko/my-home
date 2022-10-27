source $HOME/.bashrc
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(tmux fzf timer zsh-interactive-cd)

if [[ -n "$DISPLAY" && -z "$ZSH_TMUX_AUTOSTART" ]]; then
   ZSH_TMUX_AUTOSTART=true
fi

ZSH_TMUX_CONFIG=~/.config/tmux/tmux.conf

source $ZSH/oh-my-zsh.sh

alias vim="nvim"
alias x='startx'

PROMPT='%{$fg_bold[white]%}$USER@%{$fg[yellow]%}%m%}%{$fg_bold[cyan]%} %c $(git_prompt_info)%{$reset_color%}'

