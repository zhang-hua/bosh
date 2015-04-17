require 'set'

module Bosh
  module Director
    module Manifests
      class IaasManifest
        include ValidationHelper
        KEYS = ['resource_pools','compilation','properties','disk_pools','networks']

        def self.from_deployment_manifest(deployment_manifest)
          iaas_manifest = {}
          KEYS.each do |key|
            iaas_manifest[key] = deployment_manifest[key] if deployment_manifest.has_key? key
          end
          iaas_manifest
        end

        def initialize(iaas_manifest)
          @iaas_manifest = iaas_manifest
        end

        def clean
          safe_property(@iaas_manifest, 'compilation', :class => Hash)
          clean_disk_pools
          clean_resource_pools
          clean_networks

          @iaas_manifest
        end

        private

        def clean_disk_pools
          @iaas_manifest['disk_pools'] = safe_property(@iaas_manifest, 'disk_pools', :class => Array, :default => [])
          names = Set.new
          @iaas_manifest['disk_pools'].each do |pool|
            name = safe_property(pool, 'name', :class => String)
            safe_property(pool, 'disk_size', :class => Integer)
            raise DeploymentDuplicateDiskPoolName if names.include? name
            names << name
          end
        end

        def clean_resource_pools
          pools = safe_property(@iaas_manifest, 'resource_pools', :class => Array)
          names = Set.new
          pools.each do |pool|
            name = safe_property(pool, 'name', :class => String)
            raise DeploymentDuplicateResourcePoolName if names.include? name
            names << name
          end
        end

        def clean_networks
          safe_property(@iaas_manifest, 'networks', :class => Array)
          if @iaas_manifest['networks'].empty?
            raise DeploymentNoNetworks, 'No networks specified'
          end

          dns_helper = DnsHelper.new
          canonical_names = Set.new
          @iaas_manifest['networks'].each_index do |i|
            name = safe_property(@iaas_manifest['networks'][i], 'name', :class => String)
            canonical_name = dns_helper.canonical(name)
            raise DeploymentCanonicalNetworkNameTaken if canonical_names.include? canonical_name
            canonical_names << canonical_name
            type = safe_property(@iaas_manifest['networks'][i], 'type', :class => String,
              :default => 'manual')
            @iaas_manifest['networks'][i]['type'] = type
          end
        end

        private

        class DnsHelper
          include  Bosh::Director::DnsHelper
        end
      end
    end
  end
end
