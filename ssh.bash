#!/usr/bin/env bash
# pass ssh - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2019 Pierre PENNINCKX <ibizapeanut@gmail.com>.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


PASSWORD_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"


die() {
    echo "$@"
    exit 1
}


cmd_ssh_usage() {
    cat <<-_EOF
    $(cmd_ssh_short_usage)
        Provide an interactive solution to create ssh private and public
        keypairs with passphrases stored in pass as well as write the
        public key to stdout. It will show all available ssh keys in
        either fzf and wait for the user to select one and write
        the public key to stdout.

        If the selected key file does not exist under the directory
        given by --ssh-dir, first a passphrase will be generated in pass
        under the prefix given by --pass-prefix. Specific passphrase
        length can be given using --passphrase-length and no symbols can
        be activated with --passphrase-no-symbols. Second, a new private
        and public keypair will be generated with the aforementioned
        passphrase and with ssh-keygen's -t and -b option given
        respectively by --ssh-t and --ssh-b. Lastly, the public key is
        written to stdout.

        If the selected key exists, the public key is simply writeen to
        stdout.

    Needed:
        Fzf is to be installed for it to work. This is meant to be
        compatible only with MacOS. One can change line 117 if they
        want to use 'gfind' from 'findutils' (on homebrew) to print the
        ssh keys.

    Options:
        -d, --ssh-dir                Directory holding ssh keyfiles,
                                     default $HOME/.ssh.
        -p, --pass-prefix            Prefix under which passphrase are
                                     stored in pass, default sshkey-passphrase.
        -n, --passphrase-no-symbols  Do not use any non-alphanumeric characters
                                     to generate the passphrase.
        -l, --passphrase-length      Length of the passphrase to be generated.
        --ssh-t                      ssh-keygen's -t option, the type of key
                                     to create.
        --ssh-b                      ssh-keygen's -b option, the number of bits
                                     in the key to create.
_EOF
    exit 0
}

cmd_ssh_short_usage() {
    echo "Usage: pass ssh [--help,-h]" \
        "[--ssh-dir <s>,-d <s>]" \
        "[--pass-prefix <s>,-p <s>]" \
        "[--passphrase-no-symbols,-n]" \
        "[--passphrase-length <s>,-l <s>]" \
        "[--ssh-t <s>]" \
        "[--ssh-b <s>]"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1 || exit 1
}

cmd_ssh() {
    # Parse arguments
    local opts fzf=1
    local symbols="" length="25"
    local ssh_dir="$HOME/.ssh"
    local pass_prefix="sshkey-passphrase"
    local ssh_type="rsa"
    local ssh_bits=4096
    opts="$($GETOPT -o frd:p:nl: -l fzf,ssh-dir:,pass-prefix:,passphrase-no-symbols,passphrase-length:,ssh-t:,ssh-b: -n "$PROGRAM $COMMAND" -- "$@")"
    local err=$?
    eval set -- "$opts"

    while true; do case "$1" in
            -f|--fzf) fzf=1; shift ;;
            -d|--ssh-dir) ssh_dir="$2"; shift 2 ;;
            -p|--pass-prefix) pass_prefix="$2"; shift 2 ;;
            -n|--passphrase-no-symbols) symbols="--no-symbols"; shift ;;
            -l|--passphrase-length) length="$2"; shift 2 ;;
            --ssh-t) ssh_type="$2"; shift 2 ;;
            --ssh-b) ssh_bits="$2"; shift 2 ;;
            --) shift; break ;;
    esac done

    [[ $err -ne 0 ]] && die "$(cmd_ssh_short_usage)"

    local prompt="Select a ssh key:"
    local fzf_cmd="fzf --print-query --prompt=\"$prompt\" | tail -n1"
    menu="$fzf_cmd"

    # NOTE: Alternative way to print keys using `findutils` from homebrew
    # ssh_key=$(gfind "$ssh_dir" -name '*.pub' -printf '%P\n' \
    ssh_key=$(find "$ssh_dir" -name '*.pub' -print0 | xargs -0 basename \
        | sed -e 's/.pub$//' \
        | eval "$menu" )

    if [ -z "$ssh_key" ]; then
        die 'No ssh key selected.'
    fi

    local private_key="$HOME/.ssh/$ssh_key"
    local public_key="$private_key.pub"

    if ! [ -f "$public_key"  ]; then
        if [ -f "$private_key"  ]; then
            die "Will not overwrite private key $private_key, aborting."
        fi

        echo "Creating passphrase in $pass_prefix/$ssh_key"
        pass generate "$pass_prefix/$ssh_key" $symbols "$length" >/dev/null

        passphrase=$(pass show "$pass_prefix/$ssh_key" | xargs -0 echo -n)
        if [ -z "$passphrase" ]; then
            die "Failed to create passphrase."
        fi

        echo "Generating ssh key $private_key"
        ssh-keygen -t "$ssh_type" -b "$ssh_bits" -f "$private_key" -N "$passphrase" </dev/null || exit 1
    fi

    xargs -0 echo -n < "$public_key"
}

[[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]] && cmd_ssh_usage
cmd_ssh "$@"
