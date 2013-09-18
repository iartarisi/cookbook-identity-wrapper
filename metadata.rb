name             'identity-wrapper'
maintainer       'SUSE Linux'
maintainer_email 'cloud-devel@suse.de'
license          'Apache 2.0'
description      'Wraps the openstack-identity cookbook for crowbar barclamps'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

%w{ suse }.each do |os|
  supports os
end

depends "openstack-identity", "~> 7.0.0"
