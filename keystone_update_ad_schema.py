# Copyright 2015 Cloudbase Solutions Srl
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

import ldap

ldap_server = "ldap://localhost"
ldap_domain = "DC=osdemo,DC=local"
ldap_user = "OSDEMO\\Administrator"
ldap_password = "Passw0rd"

cn = "CN=Organizational-Role,CN=Schema,CN=Configuration,%s" % ldap_domain

l = ldap.initialize(ldap_server)
l.simple_bind_s(ldap_user, ldap_password)
org_role = l.search_s(cn, ldap.SCOPE_BASE)[0]

if not "groupOfNames" in org_role[1].get("possSuperiors", []):
    l.modify_s(cn, [(ldap.MOD_ADD, 'possSuperiors', 'groupOfNames')])

l.unbind()
