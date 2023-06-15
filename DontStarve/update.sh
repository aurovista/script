#!/bin/bash
tmux send-keys -t dontstarve2 'c_save()' C-m
tmux send-keys -t dontstarve2 'c_shutdown()' C-m
tmux send-keys -t dontstarve2 'c_shutdown()' C-m
~/steamcmd/steamcmd.sh +login anonymous +force_install_dir ~/dontstarvetogether_dedicated_server/ +app_update 343050 validate +quit
tmux send-keys -t dontstarve2 '~/start2.sh' C-m