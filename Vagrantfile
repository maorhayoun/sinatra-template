# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box = "precise32"
  config.vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  config.vm.customize ["modifyvm", :id, "--natdnsproxy1", "on"]  

  config.vm.network :hostonly, "192.168.33.11"

  # config.vm.forward_port 80, 8080

   config.vm.provision :chef_solo do |chef|
      chef.cookbooks_path = "cookbooks"
  #   chef.roles_path = "../my-recipes/roles"
  #   chef.data_bags_path = "../my-recipes/data_bags"
  #   chef.add_recipe "mysql"
  #   chef.add_role "web"
  
      chef.add_recipe "build-essential"      
      chef.add_recipe "git"
      chef.add_recipe "apt" 
      chef.add_recipe "ohai" 
      chef.add_recipe "yum" 
      chef.add_recipe "runit" 
      chef.add_recipe "nginx" 
      chef.add_recipe "unicorn" 
      chef.add_recipe "rvm::vagrant"
      chef.add_recipe "rvm::system"
 
      chef.json = {     
        "rvm" => {
          "rubies"  => ["1.9.2"],
          "global_gems" => [
              { 'name' => 'bundler' }
          ]
        }
      }

   end

end
