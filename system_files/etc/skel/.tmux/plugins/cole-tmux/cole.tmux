#!/usr/bin/env bash

# Cole colorscheme for Tmux
# A stationery-inspired theme with vintage earth tones

# Color palette
background="#101010"
foreground="#f2e6cf"
accent="#b38d59"
accent_bright="#cc9b52"
green="#2e9969"
green_bright="#66cc69"
red="#cc5d4b"
black="#121212"
border="#3d3d3d"

# Set vi style key bindings in copy mode
tmux set-option -g mode-keys vi

# Set colors to status bar
tmux set-option -g status-style "bg=$background,fg=$foreground"
tmux set-option -g status-position bottom
tmux set-option -g status-justify left

# Set window list styles
tmux set-window-option -g window-status-style "bg=$background,fg=$foreground"
tmux set-window-option -g window-status-current-style "bg=$accent,fg=$black,bold"
tmux set-window-option -g window-status-separator " "

# Format window names in list
tmux set-window-option -g window-status-format " #I: #W "
tmux set-window-option -g window-status-current-format " #I: #W "

# Panes styling
tmux set-option -g pane-border-style "fg=$border"
tmux set-option -g pane-active-border-style "fg=$accent_bright"

# Messages
tmux set-option -g message-style "bg=$black,fg=$foreground"
tmux set-option -g message-command-style "bg=$black,fg=$foreground"
tmux set-option -g prompt-cursor-colour "$foreground"

# Copy mode
tmux set-window-option -g copy-mode-match-style "bg=$green,fg=$black"
tmux set-window-option -g copy-mode-current-match-style "bg=$green_bright,fg=$black"

# Command styling
tmux set-option -g command-style "bg=$black,fg=$foreground"

# Status bar left (session info)
tmux set-option -g status-left "#[bg=$red,fg=$black,bold] #S #[bg=$background,fg=$foreground]"

# Status bar right (time and date)
tmux set-option -g status-right "#[bg=$background,fg=$foreground] %H:%M #[bg=$red,fg=$black,bold] %Y-%m-%d "
