#
# Cookbook Name:: cq
# Provider:: jcr
#
# Copyright (C) 2015 Jakub Wadolowski
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

class Chef
  class Provider
    class CqJcr < Chef::Provider
      include Cq::Helper

      # Chef 12.4.0 support
      provides :cq_jcr if Chef::Provider.respond_to?(:provides)

      def whyrun_supported?
        true
      end

      def load_current_resource
        @current_resource = Chef::Resource::CqJcr.new(new_resource.path)

        @raw_node_info = raw_node_info
        @current_resource.exist = exist?(@raw_node_info)

        @current_resource.properties(
          node_info(@raw_node_info)
        ) if current_resource.exist
      end

      def action_create
        if !current_resource.exist
          converge_by("Create #{new_resource.path} node") do
            update_via_sling(new_resource.properties)
          end
        else
          apply_update
        end
      end

      def action_delete
        if current_resource.exist
          converge_by("Delete #{new_resource.path} node") do
            delete_node
          end
        else
          Chef::Log.error(
            "Node #{new_resource.path} does not exist, so can't be deleted!"
          )
        end
      end

      def action_modify
        if current_resource.exist
          apply_update
        else
          Chef::Log.error("Node #{new_resource.path} does not exist!")
        end
      end

      def delete_node
        http_resp = http_delete(
          new_resource.instance,
          new_resource.path,
          new_resource.username,
          new_resource.password
        )

        http_response_validator(http_resp)
      end

      def apply_update
        payload = properties_diff

        if payload.empty?
          Chef::Log.info(
            "#{new_resource.path} node is already configured as defined"
          )
        else
          converge_by("Update #{new_resource.path} node") do
            update_via_sling(payload)
          end
        end
      end

      def raw_node_info
        req_path = "#{new_resource.path}.json"

        http_get(
          new_resource.instance,
          req_path,
          new_resource.username,
          new_resource.password
        )
      end

      def exist?(http_resp)
        return true if http_resp.code == '200'
        false
      end

      def node_info(http_resp)
        json_to_hash(http_resp.body)
      end

      def merged_new_resource_properties
        current_resource.properties
          .merge(new_resource.properties)
      end

      def update_via_sling(payload)
        http_resp = http_multipart_post(
          new_resource.instance,
          new_resource.path,
          new_resource.username,
          new_resource.password,
          payload
        )

        http_response_validator(http_resp)
      end

      def http_response_validator(http_resp)
        Chef::Application.fatal!(
          "Something went wrong during operation on #{new_resource.path}\n"\
          "HTTP response code: #{http_resp.code}\n"\
          "HTTP response body: #{http_resp.body}\n"\
          'Please check error.log file to get more info.'
        ) unless http_resp.code.start_with?('20')
      end

      def regular_diff
        diff = {}

        merged_new_resource_properties.each do |k, v|
          diff[k] = v if current_resource.properties[k] != v
        end

        diff
      end

      # Sling documentation says that jcr:lastModified and jcr:lastModifiedBy
      # are created automatically, but but I haven't seen them in CQ/AEM.
      # Instead cq:lastModified and cq:lastModified are created. Just in case I
      # decided to exclude both.
      #
      # http://sling.apache.org/documentation/bundles/manipulating-content-the-
      # slingpostservlet-servlets-post.html#automatic-property-values-last-
      # modified-and-created-by
      def auto_properties
        %w(
          jcr:created
          jcr:createdBy
          jcr:lastModified
          jcr:lastModifiedBy
          cq:lastModified
          cq:lastModifiedBy
        )
      end

      # Get protected properties of given JCR node type
      def protected_properties(type)
        if type.nil? || type.empty?
          {}
        else
          req_path = "/jcr:system/jcr:nodeTypes/#{type}.json"

          http_resp = http_get(
            new_resource.instance,
            req_path,
            new_resource.username,
            new_resource.password
          )

          protected_properties = json_to_hash(
            http_resp.body
          )['rep:protectedProperties']

          # There's no 'rep:protectedProperties' element in CQ 5.6.1
          if protected_properties
            # Even though jcr:primaryType is protected in most cases (if not
            # all) it can be changed w/o any issues (hence it gets deleted)
            protected_properties.delete_if {|k, v| k == 'jcr:primaryType'}
          else
            {}
          end
        end
      end

      # Get jcr:primaryType from (order matters):
      # * new resource (if defined)
      # * current resource (in case of existing resouruce update)
      #
      # Return nil if none of above is possible (completely new JCR node)
      def best_primary_type
        primary_types = [
          new_resource.properties['jcr:primaryType'],
          current_resource.properties['jcr:primaryType']
        ]

        primary_types.each do |t|
          return t if t
        end

        return nil
      end

      # Check whether given property is editable
      def editable_property(name)
        # Get protected properties of given JCR type. Has to be fetched just
        # once
        @protected_properties ||= protected_properties(best_primary_type)

        !auto_properties.include?(name) &&
          !@protected_properties.include?(name)
      end

      def force_replace_diff
        diff = {}

        # Iterate over desired (new) properties first to see if update is
        # required
        new_resource.properties.each do |k, v|
          diff[k] = v if current_resource.properties[k] != v
        end

        # Mark for deletion all properties that are currently present, but are
        # not defined in desired (new) state
        current_resource.properties.each do |k, _v|
          diff["#{k}@Delete"] = '' if !new_resource.properties[k]
        end

        diff
      end

      def properties_diff
        diff = {}

        if new_resource.append
          diff = regular_diff
        else
          diff = force_replace_diff
        end

        # Get rid of keys (properties) that are protected or automatically
        # created
        diff.delete_if do |k, _v|
          !editable_property(k.gsub(/@Delete/, ''))
        end
      end
    end
  end
end