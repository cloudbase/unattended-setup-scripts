#!/bin/sh
set -e

# This returns the list of users with permissions on ha-folder-root
# TODO: find a way to return the full users list, if possible 
vim-cmd vimsvc/auth/entity_permissions vim.Folder:ha-folder-root | sed -rn 's/\ +principal = "(.+)",\ +/\1/p'
