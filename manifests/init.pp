# Installing development packages and bootstrap the OS
class bootstrap {

$deploy_user = 'deploy'
$deploy_group = 'deploy'
$package_list = ['gcc', 'gcc-c++', 'make', 'zlib-devel', 'git', 'ruby-devel', 'nano', 'httpd', 'httpd-devel', 'apr-devel', 'apr-util-devel',
'libxml2', 'libxml2-devel', 'libxslt', 'libxslt-devel', 'openssl-devel.i686', 'mysql-server', 'mysql-devel', 'memcached', 'redis']

package{$package_list: ensure => 'latest'}

user { 'deploy': groups=>'rvm', comment => 'This is the deploy user', ensure => 'present', managehome => 'true',} ->
file { '/home/deploy/.ssh': ensure => 'directory', require => User['deploy'], owner => 'deploy', mode => '700',} ->
# TODO: Add the proper SSH keys for the deploy user
file { '/web': ensure => 'directory', require => User['deploy'], owner => 'deploy', mode => '0664', } ->

file { 'httpd.conf': path => '/etc/httpd/conf/httpd.conf', ensure => file, require => Package['httpd'], content => template('/root/puppet/template/httpd.conf.erb'),} ->
file { 'sshd_config': path => '/etc/ssh/sshd_config', ensure => file, content => template('/root/puppet/template/sshd_config.erb'),} ->

service { "httpd": enable => true, ensure => running, require => Package["httpd"],} ->
service { "mysqld": enable => true, ensure => running, require => Package["mysql-server"],} ->
service { "sshd": enable => true, ensure => running,} ->

#service { "postgresql": enable => true, ensure => "running", require => Package["postgresql-server"]} ->

# Clear the iptables for firewall rules
exec { 'Clear iptables': command => 'iptables -F', path => '/sbin/'} ->
exec { 'Clear SELinux': command => 'setenforce 0', path => '/sbin/', returns => [0, 1]}
}

class {'bootstrap': }
