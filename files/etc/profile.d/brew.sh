#!/usr/bin/env bash

# Set up Homebrew environment for interactive bash and POSIX-compatible shells
# Note: Zsh uses /etc/zsh/zshenv for Homebrew configuration
if [[ -d /var/home/linuxbrew/.linuxbrew && $- == *i* ]]; then
    # Interactive shell: Prioritize Homebrew binaries, but keep brew wrapper accessible
    eval "$(/var/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # Append /usr/bin to ensure the brew wrapper is still in PATH
    # but Homebrew-managed binaries take precedence
    export PATH="${PATH}:/usr/bin"

    # Alias brew to the wrapper to enforce permission controls
    # The real brew is in /var/home/linuxbrew/.linuxbrew/bin/brew but aliases take precedence
    alias brew='/usr/libexec/brew-wrapper'
fi

# Check for interactive bash and that we haven't already been sourced.
if [ "x${BASH_VERSION-}" != x -a "x${PS1-}" != x -a "x${BREW_BASH_COMPLETION-}" = x ]; then

    # Check for recent enough version of bash.
    if [ "${BASH_VERSINFO[0]}" -gt 4 ] ||
        [ "${BASH_VERSINFO[0]}" -eq 4 -a "${BASH_VERSINFO[1]}" -ge 2 ]; then
        if [ -w /var/home/linuxbrew/.linuxbrew ]; then
            if ! test -L /var/home/linuxbrew/.linuxbrew/etc/bash_completion.d/brew; then
                /var/home/linuxbrew/.linuxbrew/bin/brew completions link > /dev/null
            fi
        fi
        if test -d /var/home/linuxbrew/.linuxbrew/etc/bash_completion.d; then
            for rc in /var/home/linuxbrew/.linuxbrew/etc/bash_completion.d/*; do
                if test -r "$rc"; then
                . "$rc"
                fi
            done
            unset rc
        fi
    fi
    BREW_BASH_COMPLETION=1
    export BREW_BASH_COMPLETION
fi
