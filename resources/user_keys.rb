#
# Cookbook Name:: opsline-openvpn
# Resource:: user_keys
#
# Author:: Opsline
#
# Copyright 2015, OpsLine, LLC.
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

actions :create
default_action :create

attribute :name, :kind_of => String, :name_attribute => true
attribute :user_databag, :kind_of => String, :default => 'users'
attribute :user_query, :kind_of => String, :default => '*:*'
attribute :base_dir, :kind_of => String, :default => '/etc/openvpn'
attribute :port, :kind_of => Integer, :default => 1194
attribute :instance, :kind_of => String, :default => nil
