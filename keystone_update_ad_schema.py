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

from ldap import modlist

ldap_server = "ldap://localhost"
ldap_domain = "DC=osdemo,DC=local"
ldap_user = "OSDEMO\\Administrator"
ldap_password = "Passw0rd"

ldap_base_ou_dn = "OU=OpenStack,%s" % ldap_domain
ldap_users_ou_dn = "OU=Users,OU=OpenStack,%s" % ldap_domain
ldap_tenants_ou_dn = "OU=Tenants,OU=OpenStack,%s" % ldap_domain
ldap_roles_ou_dn = "OU=Roles,OU=OpenStack,%s" % ldap_domain


def update_schema(l, ldap_domain):
    dn = "CN=Organizational-Role,CN=Schema,CN=Configuration,%s" % ldap_domain
    org_role = l.search_s(dn, ldap.SCOPE_BASE)[0]

    if "groupOfNames" not in org_role[1].get("possSuperiors", []):
        l.modify_s(dn, [(ldap.MOD_ADD, 'possSuperiors', 'groupOfNames')])


def create_organizational_unit(l, ou_dn):
    try:
        ou = l.search_s(ou_dn, ldap.SCOPE_BASE)
        # ou exists
        return
    except ldap.NO_SUCH_OBJECT:
        pass

    attrs = {}
    attrs['objectclass'] = ['top', 'organizationalUnit']
    ldif = modlist.addModlist(attrs)
    l.add_s(ou_dn, ldif)


l = ldap.initialize(ldap_server)
l.simple_bind_s(ldap_user, ldap_password)

update_schema(l, ldap_domain)

create_organizational_unit(l, ldap_base_ou_dn)
create_organizational_unit(l, ldap_users_ou_dn)
create_organizational_unit(l, ldap_tenants_ou_dn)
create_organizational_unit(l, ldap_roles_ou_dn)

l.unbind_s()
