require 'bundler/capistrano'
default_run_options[:pty] = true
#default_run_options[:shell] = '/bin/bash --login'
ssh_options[:forward_agent] = true
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]

# RVM options
set :rvm_type, :system
set :rvm_path, '/usr/local/rvm/'

# User should be able to select which version of ruby + passenger to use
# Nginx needs to be recompiled for every new version of passenger

#set :rvm_ruby_string, 'ruby-1.9.3-p392'
#set :passenger_string, 'passenger-3.0.21'

set :rvm_ruby_string, 'ruby-1.9.3-p429'
set :passenger_string, 'passenger-4.0.5'

#set :rvm_ruby_string, 'ruby-2.0.0-p195'
#set :passenger_string, 'passenger-4.0.5'

#set :httpd, 'apache'
#set :httpd, 'nginx'

require 'rvm/capistrano'

# Application environment
set :application, 'blog'
set :repository, 'git@github.com:billxinli/blog.git'
set :repository, 'https://github.com/billxinli/blog.git'
set :scm, 'git'
set :user, 'deploy'
set :use_sudo, false
set :branch, 'master'
set :keep_releases, 2
set :deploy_via, :remote_cache

namespace :deploy do
  task :start do
    ;
  end
  task :stop do
    ;
  end

  task :apply_configs, :roles => :app do
  end

  task :restart, :roles => :app, :except => {:no_release => true} do
    run "#{try_sudo} touch #{File.join(current_path, 'tmp', 'restart.txt')}"
  end
end


# This is a sample Vagrant configuration block
# TODO: Move git repo from github to local repository to speed up the checkout process
task :vagrant do
  set :user, 'vagrant'
  set :rails_env, 'production'
  # This is where Vagrant is running on. This is configured in the Vagrantfile, look for :private_network option
  # TODO: Make sure the below is right
  set :domain, '10.10.10.10'
  set :deploy_to, "/web/#{application}"
  set :branch, 'master'
  role :web, domain
  role :app, domain
  role :db, domain, :primary => true
end

# This is a sample linode configuration block
task :production do
  set :user, 'deploy'
  set :rails_env, 'production'
  # This is where Vagrant is running on. This is configured in the Vagrantfile, look for :private_network option
  # TODO: Make sure the below is right
  set :domain, '173.230.128.67'
  set :deploy_to, "/web/#{application}"
  set :branch, 'master'
  role :web, domain
  role :app, domain
  role :db, domain, :primary => true
end

# Automation namespace
# Responsible for creating the databases and virtual host files.
namespace :automation do
  desc 'List rubies and passenger instance available'
  task :list_rubies do
    self[:packages] = {}
    # We are assuming that `rvm` is installed in /usr/local/rvm.
    # TODO: make the assumption above a fact by using `whereis rvm`
    rubies = capture('ls -1 /usr/local/rvm/gems').split(/\n|\r\n/)
    rubies.each do |ruby|
      # We only care about ruby-[version]-p[number] everything else JRuby is not considered
      if ruby.start_with?('ruby-') && !ruby.include?('@')
        self[:packages][ruby] = []
        # Determine the gems installed for the given version of ruby
        gems = capture("ls -1 /usr/local/rvm/gems/#{ruby}/gems").split(/\n|\r\n/)
        gems.each do |gem|
          # See if passenger is one of the gems installed, and record this
          if gem.start_with?('passenger-')
            self[:packages][ruby] << gem
          end
        end
      end
    end
    # Display the ruby versions installed as well as the passenger version installed
    self[:packages].each do |ruby, passengers|
      puts "#{ruby}:\n"
      passengers.each { |passenger| puts "\t - #{passenger}\n" }
    end
  end

  # TODO: Nginx
  desc 'Prepare VirtualHost file for the current application'
  task :prepare_virtualhost do
    set :user, 'root'
    automation.list_rubies
    # Make sure that the given ruby and passenger is actually installed in Vagrant
    if self[:packages].has_key?(rvm_ruby_string) && self[:packages][rvm_ruby_string].include?(passenger_string)
      passenger_major_version = Integer(passenger_string.split("-").last.split(".").first)
      # The shared object is surprisingly dumped in different folders.
      # TODO: I assumed that major version >= 4 is in `libout` while others are in `ext`... I only tested Passenger 3.
      # Passenger 2.x refused to compile on Fedora 18 with Ruby 1.9.x or 1.8.x
      if passenger_major_version >= 4
        libout = 'libout'
      else
        libout = 'ext'
      end

      # PassengerRuby: See http://www.modrails.com/documentation/Users%20guide%20Apache.html#PassengerDefaultRuby
      # Older version of Passenger will need to use PassengerRuby

      # Idea here:
      # We are going to write 2 conf files:
      # - /etc/httpd/conf.d/passenger.conf: tells apache to load the Passenger module.
      # Since Passenger will be executed against a version of ruby and a version of passenger compiled against that ruby, this is where we select the ruby version that we want to test the application against
      #
      # - /etc/httpd/conf.d/vagrant.twg.ca.conf: the virtualhost for the application.
      # RailsEnv is set here
      run %Q|
        rm /etc/httpd/conf.d/passenger.conf > /dev/null 2>%1;
        echo "LoadModule passenger_module /usr/local/rvm/gems/#{rvm_ruby_string}/gems/#{passenger_string}/#{libout}/apache2/mod_passenger.so" >> /etc/httpd/conf.d/passenger.conf;
        echo "PassengerRoot /usr/local/rvm/gems/#{rvm_ruby_string}/gems/#{passenger_string}" >> /etc/httpd/conf.d/passenger.conf;
        echo "PassengerRuby /usr/local/rvm/wrappers/#{rvm_ruby_string}/ruby" >> /etc/httpd/conf.d/passenger.conf;
        rm /etc/httpd/conf.d/vagrant.twg.ca.conf> /dev/null 2>%1;
        echo "<VirtualHost *:80>" > /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "  ServerName vagrant.twg.ca" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "  DocumentRoot /web/#{application}/current/public" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "  RailsEnv #{rails_env}" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "  <Directory /web/#{application}/current/public>" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "    AllowOverride all" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "    Options -MultiViews" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "  </Directory>" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        echo "</VirtualHost>" >> /etc/httpd/conf.d/vagrant.twg.ca.conf;
        service httpd restart|
    else
      #TODO: Write error message here
    end
  end

  desc 'Prepare the database for the current application'
  task :prepare_database do
    # Determine database.yml file exists
    if File.file?('config/database.yml')
      begin
        # Reads the database.yml for development database information
        database_yaml = YAML.load_file('config/database.yml')
        environment_database = database_yaml[rails_env]
        if environment_database['adapter'] === 'mysql2' # We are using mysql
          run %Q|
            rm /tmp/#{application}_user.sql > /dev/null 2>&1
            echo "DROP USER '#{environment_database['username']}'@'localhost';" >> /tmp/#{application}_user.sql;
            echo "CREATE DATABASE IF NOT EXISTS #{environment_database['database']};" >> /tmp/#{application}_user.sql;
            echo "CREATE USER '#{environment_database['username']}'@'localhost' IDENTIFIED BY '#{environment_database['password']}';" >> /tmp/#{application}_user.sql;
            echo "GRANT ALL PRIVILEGES ON *.* TO '#{environment_database['username']}'@'localhost' WITH GRANT OPTION;" >> /tmp/#{application}_user.sql;
            mysql -u root mysql < /tmp/#{application}_user.sql;
            rm /tmp/#{application}_user.sql > /dev/null 2>&1|
        elsif database['adapter'] === 'postgresql' # We are using postgresql
                                                   # TODO: this ^
        elsif database['adapter'] === 'sqlite3' # We are using sqlite3
                                                # Unless if you are using SEE I don't think there is any additional steps required
        end
      rescue Errno::ENOENT
        puts 'database.yml does not exist. Make sure the database.yml file is populated.'
      end
    end
  end

  desc 'Pulls the Vagrant environment info and display it'
  task :open_environment_info_in_browser do
    tmp_file = "/tmp/#{application}_environment.html"
    open(tmp_file, 'w') do |f|
      f << "<p><strong>OS Version</strong>: #{capture('cat /etc/fedora-release')}</p>"
      f << "<p><strong>MySQL Version</strong>: #{capture('mysql -V')}</p>"
      f << "<p><strong>Rails Version</strong>: #{capture('gem list')}</p>"
      f << "<p><strong>Ruby Version</strong>: #{rvm_ruby_string}</p>"
      f << "<p><strong>Passenger Version</strong>: #{passenger_string}</p>"
    end
    run_locally("open file://#{tmp_file}")
  end
end


namespace :linode do

  desc 'Prepare the current application for Linode'
  task :prepare do
    # The chain starter
  end

  desc 'Deploy the current application to Linode'
  task :go do
    # The chain starter
  end

  desc 'Created a new node on Linode with a given StackScript'
  task :create_node do
    # API Key can be grabbed from the profile tab
    api_key = 'LINODE API KEY'

    # The Linode that I have access to, alternatively, if the API key have the proper permission, create an linode.
    linode_id = 12345

    # Log into Linode
    l = Linode.new(:api_key => api_key)

    # Shutdown the Linode
    l.linode.shutdown({:LINODEID => linode_id})

    # Delete all the disks
    disks = l.linode.disk.list({:LINODEID => linode_id})
    disks.each do |disk|
      l.linode.disk.delete({:LINODEID => linode_id, :DISKID => disk.diskid})
    end

    # Give it some time for all the disks to be deleted
    # TODO: Linode have a limitation where they will not allow you to consistently create and destroy disks.
    while disks.length != 0
      sleep(5)
      disks = l.linode.disk.list({:LINODEID => linode_id})
    end

    # Delete all the configurations
    configurations = l.linode.config.list({:LINODEID => linode_id})
    configurations.each do |configuration|
      l.linode.config.delete({:LINODEID => linode_id, :CONFIGID => configuration.configid})
    end

    # Create a SWAP disk
    swap = l.linode.disk.create({:LINODEID => linode_id, :LABEL => 'Fedora 17 SWAP', :TYPE => 'swap', :SIZE => 256})

    # Create a root disk
    root = l.linode.disk.createfromstackscript ({:LINODEID => linode_id, :STACKSCRIPTID => 6835,
                                                 :STACKSCRIPTUDFRESPONSES => {
                                                     :root_ssh_key => 'ssh-rsa A',
                                                     :deploy_ssh_key => 'ssh-rsa A'
                                                 }.to_json,
                                                 :DISTRIBUTIONID => 100,
                                                 :LABEL => 'Fedora 17 ROOT From Stackscript',
                                                 :SIZE => 48896,
                                                 :ROOTPASS => 'PASSWORD'

    })

    # Create a new instance of Fedora using the stackscript
    config = l.linode.config.create({:LINODEID => linode_id, :KERNELID => 138, :LABEL => 'Fedora 17', :DISKLIST => "#{root.diskid},#{swap.diskid}"})

    # Boot it
    l.linode.boot({:LINODEID => linode_id, :CONFIGID => config.configid})

    print "Booting Linode\n"

  end

  desc 'Open the Vagrant deployed application in a local browser'
  task :open_application_in_browser do

    # We are only going to do this for OSX environment
    # TODO: Determine if Windows and non OSX flavor *nix system have the open command I can probably Google this
    host_os = RbConfig::CONFIG['host_os']
    run_locally("open http://#{domain}") if host_os.include?('darwin')
  end
end
after 'linode:prepare', 'production', 'automation:prepare_virtualhost'
after 'linode:go', 'production', 'deploy:setup', 'automation:prepare_database', 'deploy:migrations', 'automation:open_environment_info_in_browser', 'linode:open_application_in_browser'


#
# Vagrant block start
#

# The idea behind the following bits of code is:
# Use after hooks to chain all the required actions to deploy an application to Vagrant, only a single command is needed:
# `cap vagrant vm:go` which will call: `cap vagrant deploy:setup automation:prepare_virtualhost automation:prepare_database deploy:migrations automation:open_environment_info_in_browser vm:open_application_in_browser`

# To setup the Vagrant environment:
# Use Fedora, otherwise package names may need changing, ie) Apache vs httpd, imagemagick vs ImageMagick
# Disable firewall and SELinux (or AppArmor)
# Install all the compilers, headers, and misc packages, look at init.pp
# Install rvm and all versions of rubies and all versions of passenger for different rubies (`passenger-install-apache2-module` is located at /usr/local/rvm/gems/ruby-[#]-p[#]/gems/passenger-[#]/bin)
# Configure both ssh keys for deployment and ssh keys for pulling from Github on your local machine and in Vagrant
# Append the required vagrant blocks to all deploy.rb file
# configure the database.yml files, and in terminal fire `cap vagrant vm:go`
#
# Assumptions
# Database is pointed to localhost in the database.yml files
# MySQL Database's root user is `root` with no password
# The Apache conf folder (/etc/httpd/conf.d is owned by the deploy user) OR httpd.conf will load configuration files that are +rwx to the deploy user
# rvm is installed at `/usr/local/rvm`


# The namespace used for Vagrant, so not to clutter up the top namespace
namespace :vm do

  desc 'Prepare the current application for Vagrant'
  task :prepare do
    # The chain starter
  end

  desc 'Deploy the current application to Vagrant'
  task :go do
    # The chain starter
  end

  desc 'Open the Vagrant deployed application in a local browser'
  task :open_application_in_browser do
    # The assumption here is the current project is using Vagrant, thus a `Vagrantfile` must exist on the root project directory
    # And we are going to parse for the private_network
    # The default private_network is set as 10.10.10.10
    if File.exist?('Vagrantfile')
      # We are only going to do this for OSX environment
      # TODO: Determine if Windows and non OSX flavor *nix system have the open command I can probably Google this
      host_os = RbConfig::CONFIG['host_os']
      if host_os.include?('darwin')
        # This is a hack... since Vagrantfile is a valid ruby file, there should be a way of reading the contents with a Vagrant API.
        # SEE: http://stackoverflow.com/questions/16923417/read-vagrantfile-programatically-with-ruby
        # TODO: Unhack this
        s = File.open('Vagrantfile', 'rb') { |f| f.read }
        private_network_index_start = s.index(':private_network')
        private_network_index_end = s.index("\n", private_network_index_start) +1
        private_network_config_line = s.slice(private_network_index_start, private_network_index_end-private_network_index_start)
        ip_regex = /([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])*){3}/
        private_ip = private_network_config_line.match(ip_regex)
        if private_ip
          run_locally("open http://#{private_ip}")
        else
          puts 'Private IP is not configured in Vagrantfile.'
        end
      end
    else
      puts 'Vagrantfile not found in the project root.'
    end
  end
end

after 'vm:prepare', 'vagrant', 'automation:prepare_virtualhost'
after 'vm:go', 'vagrant', 'deploy:setup', 'automation:prepare_database', 'deploy:migrations', 'automation:open_environment_info_in_browser', 'vm:open_application_in_browser'
#
# Vagrant block end
#

after 'deploy:update_code', 'deploy:apply_configs'
after 'deploy', 'deploy:cleanup'