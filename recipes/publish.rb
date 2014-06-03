#
# Cookbook Name:: cq
# Recipe:: publish
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

# Make sure that all prerequisites are in place
# -----------------------------------------------------------------------------
include_recipe 'cq::commons'

# Install CQ instance
# -----------------------------------------------------------------------------
cq_installer "CQ #{node[:cq][:publish][:mode]}" do
  mode node[:cq][:publish][:mode]
end

# Create a daemon and start CQ instance
# -----------------------------------------------------------------------------
cq_daemon "CQ #{node[:cq][:publish][:mode]}" do
  mode node[:cq][:publish][:mode]
end