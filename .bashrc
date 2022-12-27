PATH="$HOME/bin"
PATH+=":$HOME/.config/composer/vendor/bin"
PATH+=":$HOME/.local/bin"
PATH+=":$HOME/.npm-local/bin"
PATH+=":/usr/local/bin"
PATH+=":/usr/bin"
PATH+=":/bin"

if [[ -n "${TERM}" && "${TERM}" != 'dumb' ]]; then
    PS1="\[$(tput bold)\]"
    PS1+="\[$(tput setaf 7)\]["
    PS1+="\[$(tput setaf 3)\]\u"
    PS1+="\[$(tput setaf 7)\]@"
    PS1+="\[$(tput setaf 4)\]\h "
    PS1+="\[$(tput setaf 2)\]\W"
    PS1+="\[$(tput setaf 7)\]]"
    PS1+="\[$(tput setaf 7)\]\\$ "
    PS1+="\[$(tput sgr0)\]"

    if command -v tmux > /dev/null \
        && [[ -n "${DISPLAY}" || -n "${SSH_CLIENT}" ]] \
        && [[ -z "${TMUX}" ]]
    then
        tmux attach || tmux && exit
    fi
fi

fi

alias x='startx'
