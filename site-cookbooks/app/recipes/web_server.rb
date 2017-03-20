#
# Cookbook Name:: app
# Recipe:: web_server
#
# Copyright 2013, Mathias Hansen
# Copyright 2015, joschi127
#

# Install Apache
include_recipe "openssl"
include_recipe "apache2"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"
include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"
include_recipe "apache2::mod_headers"
include_recipe "apache2::mod_expires"

# Install PHP
include_recipe "php"
include_recipe "php::module_gd"
include_recipe "php::module_mysql"
include_recipe "php::module_pgsql"
include_recipe "php::module_sqlite3"
include_recipe "php::module_curl"
include_recipe "php::module_ldap"
#include_recipe "apache2::mod_php"

# Install extra php packages
['imagemagick', 'php-imagick', 'libapache2-mod-php7.0', 'php-intl', 'php-mbstring', 'php-imap', 'php-mcrypt', 'php-simplexml', 'php-memcache', 'php-redis', 'php-xdebug', 'php-dev'].each do |a_package|
  package a_package
end

# Set xdebug extra options
bash "set-xdebug-extra-options" do
  code <<-endofstring
    echo 'xdebug.remote_enable=On' > /etc/php/7.0/mods-available/xdebug-extra-options.ini
    echo 'xdebug.remote_connect_back=On' >> /etc/php/7.0/mods-available/xdebug-extra-options.ini
    echo 'xdebug.remote_autostart=Off' >> /etc/php/7.0/mods-available/xdebug-extra-options.ini
    echo 'xdebug.max_nesting_level=500' >> /etc/php/7.0/mods-available/xdebug-extra-options.ini
    echo 'xdebug.var_display_max_depth=5' >> /etc/php5/mods-available/xdebug-extra-options.ini
    echo 'xdebug.var_display_max_children=256' >> /etc/php5/mods-available/xdebug-extra-options.ini
    echo 'xdebug.var_display_max_data=1024' >> /etc/php5/mods-available/xdebug-extra-options.ini
    ln -sf /etc/php/7.0/mods-available/xdebug-extra-options.ini /etc/php/7.0/apache2/conf.d/99-xdebug-extra-options.ini
    ln -sf /etc/php/7.0/mods-available/xdebug-extra-options.ini /etc/php/7.0/cli/conf.d/99-xdebug-extra-options.ini
  endofstring
end

# Disable xdebug for composer
bash "disable-xdebug-for-composer" do
  code <<-endofstring
    if ! grep -q "alias composer=" /home/webserver/.bashrc
    then
      echo >> /home/webserver/.bashrc
      echo "# composer without xdebug" >> /home/webserver/.bashrc
      echo "alias composer='COMPOSER_DISABLE_XDEBUG_WARN=1 php -d xdebug.remote_enable=0 -d xdebug.profiler_enable=0 -d xdebug.default_enable=0 /usr/local/bin/composer'" >> /home/webserver/.bashrc
    fi
  endofstring
end

# Fix php.ini, do not use disable_functions
bash "fix-php-ini-disable-functions" do
  code "find /etc/php/7.0/ -name 'php.ini' -exec sed -i -re 's/^(\\s*)disable_functions(.*)/\\1;disable_functions\\2/g' {} \\;"
  notifies :restart, resources("service[apache2]"), :delayed
end

# Set php ini settings
execute "ini-settings-init" do
  command "echo -n > /etc/php/7.0/mods-available/chef-ini-settings.ini"
end
node['php']['ini_settings'].each do |key, value|
  execute "ini-settings-add-#{key}" do
    command "echo '#{key} = #{value}' >> /etc/php/7.0/mods-available/chef-ini-settings.ini"
  end
end
bash "ini-settings-enable" do
  code <<-endofstring
    ln -sf /etc/php/7.0/mods-available/chef-ini-settings.ini /etc/php/7.0/apache2/conf.d/99-chef-ini-settings.ini
    ln -sf /etc/php/7.0/mods-available/chef-ini-settings.ini /etc/php/7.0/cli/conf.d/99-chef-ini-settings.ini
  endofstring
end

# Install Composer
include_recipe "composer"
