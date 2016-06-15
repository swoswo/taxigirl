#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
"""
module: graphite_event.

description:
   - Create Event in graphite
author: Facundo Guerrero
short_description: Create Event in Graphite
requirements: [ urllib2, json ]
url: https://raw.githubusercontent.com/guerremdq/ansible-graphite-events/master/library/graphite_event
"""
import json
import urllib2

from ansible.module_utils.basic import *
from ansible.module_utils.urls import *


def main():
    """Send event to Graphite backend."""

    module = AnsibleModule(argument_spec=dict(tags=dict(required=True),
                                              url=dict(required=True),
                                              msg=dict(required=True)),
                           supports_check_mode=True)

    tags = module.params['tags']
    url = module.params['url']
    data = {}
    data['what'] = module.params['msg']
    data['tags'] = tags
    payload = json.dumps(data)

    request = urllib2.Request(url, payload, {'Content-Type':
                                             'application/json'})
    urllib2.urlopen(request)

    changed = True
    module.exit_json(changed=changed)


if __name__ == '__main__':
    main()
