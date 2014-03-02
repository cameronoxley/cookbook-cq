# ~FC015
#
# Cookbook Name:: cq
# Definition:: installer
#
# Copyright (C) 2014 Jakub Wadolowski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'pathname'
require 'uri'

define :cq_installer,
       :mode => nil do

  # Helpers
  # ---------------------------------------------------------------------------
  instance_home = "#{node[:cq][:home_dir]}/#{params[:mode]}"
  jar_name = Pathname.new(URI.parse(node[:cq][:jar][:url]).path).basename.to_s

  # Create CQ instance directory
  # ---------------------------------------------------------------------------
  directory instance_home do
    owner node[:cq][:user]
    group node[:cq][:group]
    mode '0750'
    action :create
  end

  # Download and unpack CQ JAR file
  # ---------------------------------------------------------------------------
  remote_file "#{instance_home}/#{jar_name}" do
    owner node[:cq][:user]
    group node[:cq][:group]
    mode '0644'
    source node[:cq][:jar][:url]
    checksum node[:cq][:jar][:checksum]
  end

  # Unpack CQ JAR file once downloaded
  bash 'Unpack CQ JAR file' do
    user node[:cq][:user]
    group node[:cq][:group]
    cwd instance_home
    code "java -jar #{jar_name} -unpack"
    action :run

    # Do not unpack if crx-quickstart exists inside CQ instance home
    not_if { ::Dir.exist?("#{instance_home}/crx-quickstart") }
  end

  # Deploy CQ license file
  # ---------------------------------------------------------------------------
  remote_file "#{instance_home}/license.properties" do
    owner node[:cq][:user]
    group node[:cq][:group]
    mode '0644'
    source node[:cq][:license][:url]
    checksum node[:cq][:license][:checksum]
  end
end
