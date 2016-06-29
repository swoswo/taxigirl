# https://raw.githubusercontent.com/ansible/ansible/devel/lib/ansible/plugins/callback/osx_say.py
# (C) 2012, Michael DeHaan, <michael.dehaan@gmail.com>

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

# Make coding more python3-ish
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import subprocess
import os

from ansible.plugins.callback import CallbackBase

FAILED_VOICE="Zarvox"
REGULAR_VOICE="Trinoids"
HAPPY_VOICE="Cellos"
LASER_VOICE="Princess"
SAY_CMD="/usr/bin/say"

class CallbackModule(CallbackBase):
    """
    makes Ansible much more exciting on OS X.
    """
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'osx_say'
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):

        super(CallbackModule, self).__init__()

        # plugin disable itself if say is not present
        # ansible will not call any callback if disabled is set to True
        if not os.path.exists(SAY_CMD):
            self.disabled = True
            self._display.warning("%s does not exist, plugin %s disabled" % (SAY_CMD, os.path.basename(__file__)) )

    def say(self, msg, voice):
        subprocess.call([SAY_CMD, msg, "--voice=%s" % (voice)])

    def runner_on_failed(self, host, res, ignore_errors=False):
        self.say("Play failed on host %s" % host, FAILED_VOICE)

    def playbook_on_stats(self, stats):
        self.say("Play is complete", HAPPY_VOICE)
