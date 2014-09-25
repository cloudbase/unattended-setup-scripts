#!/usr/bin/python

# Copyright 2013 Cloudbase Solutions Srl
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import getopt
import sys

from winrm import protocol


def print_usage():
    print ("%s -U <url> -u <username> -p <password> <cmd> [cmd_args]" %
           sys.argv[0])


def parse_args():

    username = None
    password = None
    url = None
    cmd = None

    try:
        show_usage = False
        opts, args = getopt.getopt(sys.argv[1:], "hU:u:p:c:")
        for opt, arg in opts:
            if opt == "-h":
                show_usage = True
            if opt == "-U":
                url = arg
            elif opt == "-u":
                username = arg
            elif opt == "-p":
                password = arg

        cmd = args

        if show_usage or not (url and username and password and cmd):
            print_usage()

    except getopt.GetoptError:
        print_usage()

    return (url, username, password, cmd)


def run_wsman_cmd(url, username, password, cmd):
    protocol.Protocol.DEFAULT_TIMEOUT = "PT3600S"

    p = protocol.Protocol(endpoint=url,
                          transport='plaintext',
                          username=username,
                          password=password)

    shell_id = p.open_shell()

    command_id = p.run_command(shell_id, cmd[0], cmd[1:])
    std_out, std_err, status_code = p.get_command_output(shell_id, command_id)

    p.cleanup_command(shell_id, command_id)
    p.close_shell(shell_id)

    return (std_out, std_err, status_code)


def main():
    exit_code = 0

    url, username, password, cmd = parse_args()
    if not (url and username and password and cmd):
        exit_code = 1
    else:
        std_out, std_err, exit_code = run_wsman_cmd(url, username, password,
                                                    cmd)
        sys.stdout.write(std_out)
        sys.stderr.write(std_err)

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
