#!/bin/bash

# * emacs-sandbox.sh --- Run Emacs in a sandbox

# URL: https://github.com/alphapapa/emacs-sandbox.sh
# Version: 0.1-pre

# * Commentary

# Run Emacs in a sandbox.  Some code copied from MELPA's Makefile.

# * License:

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# * Constants

package_archives_args=(
    --eval "(add-to-list 'package-archives '(\"gnu\" . \"https://elpa.gnu.org/packages/\") t)"
    --eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t)"
)

org_package_archives_args=(
    --eval "(add-to-list 'package-archives '(\"org\" . \"https://orgmode.org/elpa/\") t)"
)

package_refresh_args=(
    --eval "(package-refresh-contents)"
)
package_init_args=(
    --eval "(package-initialize)"
)

# * Functions

function debug {
    if [[ $debug ]]
    then
        function debug {
            echo "DEBUG: $@" >&2
        }
        debug "$@"
    else
        function debug {
            true
        }
    fi
}
function error {
    echo "ERROR: $@" >&2
    ((errors++))  # Initializes automatically
}
function die {
    error "$@"
    exit $errors
}

function usage {
    cat <<EOF
$0 [OPTIONS] [EMACS-ARGS]

Run Emacs in a "sandbox" user-emacs-directory.  If no directory is
specified, one is made with "mktemp -d" and removed when Emacs exits.

Options
  --debug     Show debug information and don't remove temp directory.
  -h, --help  This.
  --          Optionally used to separate script arguments from
              Emacs arguments.

  -d, --dir DIR          Use DIR as user-emacs-directory.

  -i, --install PACKAGE      Install PACKAGE.
  -O, --no-org-repo          Don't use the orgmode.org ELPA repo.
  -P, --no-package           Don't initialize the package system.
  -R, --no-refresh-packages  Don't refresh package lists.

EOF
}

function cleanup {
    # Remove temporary paths (${temp_paths[@]}).
    for path in "${temp_paths[@]}"
    do
        if [[ $debug ]]
        then
            debug "Debugging enabled: not deleting temporary path: $path"
        elif [[ -r $path ]]
        then
            rm -rf "$path"
        else
            debug "Temporary path doesn't exist, not deleting: $path"
        fi
    done
}

# * Args

args=$(getopt -n "$0" -o d:hi:OPR -l dir:,debug,help,install:,no-package,no-org-repo,no-refresh-packages -- "$@") || { usage; exit 1; }
eval set -- "$args"

while true
do
    case "$1" in
        --debug)
            debug=true
            ;;
        -d|--dir)
            shift
            user_dir="$1"
            ;;
        -h|--help)
            usage
            exit
            ;;
        -i|--install)
            shift
            install_packages_args+=(--eval "(package-install '$1)")
            ;;
        -O|--no-org-repo)
            unset org_package_archives_args
            ;;
        -P|--no-package)
            unset package_init_args
            ;;
        -R|--no-refresh-packages)
            unset package_refresh_args
            ;;
        --)
            # Remaining args (required; do not remove)
            shift
            rest=("$@")
            break
               ;;
    esac

    shift
done

debug "ARGS: $args"
debug "Remaining args: ${rest[@]}"

# * Main

trap cleanup EXIT INT TERM

# Check or make user-emacs-directory.
if [[ $user_dir ]]
then
    # Directory given as argument: ensure it exists.
    if ! [[ -d $user_dir ]]
    then
        # Directory doesn't exist: make it and say so.
        echo "Directory doesn't exist.  Creating it: $user_dir" >&2
        mkdir "$user_dir" || die "Unable to make directory: $user_dir"
    fi
else
    # Not given: make temp directory, and delete it on exit.
    user_dir=$(mktemp -d) || die "Unable to make temp dir."
    temp_paths+=("$user_dir")
fi

# Set frame title.
title_args=(--title "Emacs (sandbox: $user_dir)")

# Make argument to load init file if it exists.
init_file="$user_dir/init.el"
[[ -r $init_file ]] && load_init_file=(--load "$init_file")

# Prepare args.
basic_args=(
    --quick
    "${title_args[@]}"
    --eval "(setq user-emacs-directory (file-truename \"$user_dir\"))"
    --eval "(setq user-init-file (file-truename \"$init_file\"))"
    "${load_init_file[@]}"
    -l package
)
emacs_args=(
    "${basic_args[@]}"
    "${package_archives_args[@]}"
    "${org_package_archives_args[@]}"
    "${package_refresh_args[@]}"
    "${package_init_args[@]}"
    "${install_packages_args[@]}"
    "${rest[@]}"
)

# Actually run Emacs.
debug "Running: emacs ${emacs_args[@]}"

emacs "${emacs_args[@]}"
