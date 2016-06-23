#!/usr/bin/env python
# (c) 2012, Peter Sankauskas
# 2016, Tom Hensel <github@jitter.eu>
#
# This file is part of Ansible,
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
#
# NOTE: this file is based on the original ansible EC2 inventory, see
#
"""Amazon EC2 Inventory Module"""
import argparse
import os

from ansible_ec2_inventory import Ec2Inventory

PWD = os.path.dirname(os.path.realpath(__file__))


def parse_cli_args():
    """Command line argument processing"""
    parser = argparse.ArgumentParser(
        description='Produce an Ansible Inventory file based on EC2')
    parser.add_argument('--config',
                        metavar='CONFIGFILE',
                        default=PWD + '/ec2_py.ini',
                        help='Config file (default: $PWD/ec2_py.ini)')
    parser.add_argument('--list',
                        action='store_true',
                        default=True,
                        help='List all instances')
    parser.add_argument('--host',
                        action='store',
                        help='Get all the variables about a specific instance')
    parser.add_argument('--refresh-cache',
                        action='store_true',
                        default=False,
                        help='Force refresh of cache by making API requests '
                        'to EC2 (default: False - use cache files)')
    parser.add_argument('--boto-profile',
                        action='store',
                        help='Use boto profile for connections to EC2')
    return parser.parse_args()


def main():
    """Run the script"""
    # Parse cli args
    args = parse_cli_args()

    # Instantiate Ec2Inventory
    inventory = Ec2Inventory(configfile=args.config,
                             refresh_cache=args.refresh_cache,
                             boto_profile=args.boto_profile)

    # Print data
    if args.host is not None:
        inventory.print_host(args.host)
    else:
        inventory.print_inventory()


if __name__ == '__main__':
    main()
