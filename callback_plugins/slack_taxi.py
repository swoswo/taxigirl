# https://raw.githubusercontent.com/FreeFeed/freefeed-ansible/freefeed/plugins/callback/slack.py
# (C) 2014-2015, Matt Martz <matt@sivel.net>
# (C) 2016, Ivan Dyachkov <ivan@dyachkov.org>
#     2016, Tom Hensel <github@jitter.eu>
#
# This file is part of Ansible
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

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

try:
    from __main__ import cli
except ImportError:
    cli = None

from ansible.constants import mk_boolean
from ansible.module_utils.urls import open_url
from ansible.plugins.callback import CallbackBase

import json
import os
import uuid
import socket

SLACK_INCOMING_WEBHOOK = 'https://hooks.slack.com/services/%s'

try:
    import prettytable
    HAS_PRETTYTABLE = True
except ImportError:
    HAS_PRETTYTABLE = False

class CallbackModule(CallbackBase):
    """This is an ansible callback plugin that sends status
    updates to a Slack channel during playbook execution.

    This plugin makes use of the following environment variables:
        SLACK_TOKEN       (required): Slack Webhook URL
        SLACK_CHANNEL     (optional): Slack room to post in. Default: #ansible
        SLACK_USERNAME    (optional): Username to post as. Default: ansible
        SLACK_INVOCATION  (optional): Show command line invocation
                                      details. Default: False

    Requires:
        prettytable

    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'slack'
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):

        self.disabled = False

        if cli:
            self._options = cli.options
        else:
            self._options = None

        super(CallbackModule, self).__init__()

        if not HAS_PRETTYTABLE:
            #self.disabled = True
            self._display.warning('The `prettytable` python module is not '
                                  'installed. Disabling the Slack callback '
                                  'plugin.')

        self.token = os.getenv('SLACK_TOKEN')
        self.channel = os.getenv('SLACK_CHANNEL', '#automation')
        self.username = os.getenv('SLACK_USERNAME', 'ansible')
        self.show_invocation = mk_boolean(
            os.getenv('SLACK_INVOCATION', self._display.verbosity > 1)
        )

        if self.token is None:
            #self.disabled = True
            self._display.warning('Slack token was not provided. The '
                                  'Slack token can be provided using '
                                  'the `SLACK_TOKEN` environment '
                                  'variable.')

        self.playbook_name = None

        # This is a 6 character identifier provided with each message
        # This makes it easier to correlate messages when there are more
        # than 1 simultaneous playbooks running
        self.guid = uuid.uuid4().hex[:6]

    def send_msg(self, attachments):
        payload = {
            'channel': self.channel,
            'username': self.username,
            'attachments': attachments,
            'parse': 'none'
        }

        data = json.dumps(payload)
        # DEBUG
        self._display.debug(data)
        try:
            webhook_url = SLACK_INCOMING_WEBHOOK % (self.token)
            response = open_url(webhook_url, data=data)
            # DEBUG
            self._display.debug(response)
            return response.read()
        except Exception as e:
            self._display.warning('Could not submit message to Slack: %s, URL: %s' % (str(e), webhook_url))

    def v2_playbook_on_start(self, playbook):
        self.playbook_name = os.path.basename(playbook._file_name)

        title = [
            'Playbook %s started on %s' % (playbook._file_name, socket.gethostname())
        ]
        invocation_items = []
        if self._options and self.show_invocation:
            tags = self._options.tags
            skip_tags = self._options.skip_tags
            extra_vars = self._options.extra_vars
            subset = self._options.subset
            inventory = os.path.basename(
                os.path.realpath(self._options.inventory)
            )

            invocation_items.append('Inventory:  %s' % inventory)
            if tags and tags != 'all':
                invocation_items.append('Tags:       %s' % tags)
            if skip_tags:
                invocation_items.append('Skip Tags:  %s' % skip_tags)
            if subset:
                invocation_items.append('Limit:      %s' % subset)
            if extra_vars:
                invocation_items.append('Extra Vars: %s' %
                                        ' '.join(extra_vars))

            title.append('by *%s*' % self._options.remote_user)

        title.append('\n\n*%s*' % self.playbook_name)
        msg_items = [' '.join(title)]
        if invocation_items:
            msg_items.append('```\n%s\n```' % '\n'.join(invocation_items))

        msg = '\n'.join(msg_items)

        attachments = [{
            'fallback': msg,
            'fields': [
                {
                    'value': msg
                }
            ],
            'color': 'warning',
            'mrkdwn_in': ['text', 'fallback', 'fields'],
        }]

        self.send_msg(attachments=attachments)

    def v2_playbook_on_play_start(self, play):
        pass

    def v2_runner_on_failed(self, result, ignore_errors=False):
        msg = 'Task failed: %s' % (result._result)
        attachments = [
            {
                'fallback': msg,
                'text': msg,
                'color': 'error',
                'mrkdwn_in': ['text', 'fallback', 'fields'],
            }
        ]
        self.send_msg(attachments=attachments)

    def v2_runner_item_on_failed(self, result, ignore_errors=False):
        msg = 'Item failed: %s' % (result._result)
        attachments = [
            {
                'fallback': msg,
                'text': msg,
                'color': 'error',
                'mrkdwn_in': ['text', 'fallback', 'fields'],
            }
        ]
        self.send_msg(attachments=attachments)

    def v2_playbook_on_stats(self, stats):
        """Display info about playbook statistics"""

        hosts = sorted(stats.processed.keys())

        t = prettytable.PrettyTable(['Host', 'Ok', 'Changed', 'Unreachable',
                                     'Failures'])

        failures = False
        unreachable = False

        for h in hosts:
            s = stats.summarize(h)

            if s['failures'] > 0:
                failures = True
            if s['unreachable'] > 0:
                unreachable = True

            t.add_row([h] + [s[k] for k in ['ok', 'changed', 'unreachable',
                                            'failures']])

        attachments = []
        msg_items = [
            '*Playbook Complete* (_%s_)' % self.guid
        ]
        if failures or unreachable:
            color = 'danger'
            msg_items.append('\n*Failed!*')
        else:
            color = 'good'
            msg_items.append('\n*Success!*')

        msg_items.append('```\n%s\n```' % t)

        msg = '\n'.join(msg_items)

        attachments.append({
            'fallback': msg,
            'fields': [
                {
                    'value': msg
                }
            ],
            'color': color,
            'mrkdwn_in': ['text', 'fallback', 'fields']
        })

        self.send_msg(attachments=attachments)
