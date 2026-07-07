for _p in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
    [ -f "$_p" ] && source "$_p" && break
done

for _p in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
    [ -f "$_p" ] && source "$_p" && break
done

unset _p
