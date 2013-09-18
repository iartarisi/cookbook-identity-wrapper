#
# Cookbook Name:: identity-wrapper
# Recipe:: default
#
# Copyright 2013, SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

node.override[:openstack][:developer_mode] = true
node.override[:openstack][:db][:service_type] = "postgresql"
node.override[:openstack][:db][:port] = "5432"


#### cargo culting from barclamp-keystone
env_filter = " AND database_config_environment:database-config-#{node[:keystone][:database_instance]}"
sqls = search(:node, "roles:database-server#{env_filter}") || []
if sqls.length > 0
    sql = sqls[0]
    sql = node if sql.name == node.name
else
    sql = node
end
include_recipe "database::client"
backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
include_recipe "#{backend_name}::client"
include_recipe "#{backend_name}::python-client"

db_provider = Chef::Recipe::Database::Util.get_database_provider(sql)
db_user_provider = Chef::Recipe::Database::Util.get_user_provider(sql)
privs = Chef::Recipe::Database::Util.get_default_priviledges(sql)
url_scheme = backend_name

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# TODO this used to be:
# node.set_unless['keystone']['db']['password'] = secure_password
# Figure out if we want to keep generating passwords manually here, or
# if we want to use data bags
node.set[:keystone][:db][:password] = db_password 'keystone'


sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
Chef::Log.info("Database server found at #{sql_address}")

db_conn = { :host => sql_address,
            :username => "db_maker",
            :password => sql["database"][:db_maker_password] }

# Create the Keystone Database
database "create #{node[:keystone][:db][:database]} database" do
    connection db_conn
    database_name node[:keystone][:db][:database]
    provider db_provider
    action :create
end

database_user "create keystone database user" do
    connection db_conn
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    host '%'
    provider db_user_provider
    action :create
end

database_user "grant database access for keystone database user" do
    connection db_conn
    username node[:keystone][:db][:user]
    password node[:keystone][:db][:password]
    database_name node[:keystone][:db][:database]
    host '%'
    privileges privs
    provider db_user_provider
    action :grant
end
########## end of cargo culting

node.override[:openstack][:db][:identity][:host] = sql_address
node.override[:openstack][:db][:identity][:db_type] = "postgresql"
node.override[:openstack][:db][:identity][:port] = "5432"
node.override[:openstack][:db][:identity][:password] = node[:keystone][:db][:password]

include_recipe "openstack-identity::server"
include_recipe "openstack-identity::registration"
