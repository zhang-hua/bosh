module Bosh::Director
  module DeploymentData
    class DeploymentData < Data
      attr_reader :resource_pool_names
      attr_reader :disk_pool_names
      attr_reader :network_names
      attr_reader :properties
      attr_reader :update_settings
      attr_reader :compilation_settings
    end

    class JobData < Data
      attr_reader :name
      attr_reader :canonical_name
      attr_reader :deployment_name

      attr_reader :state
      attr_reader :lifecycle_type
      attr_reader :update_settings

      attr_reader :disk_pool_name
      attr_reader :resource_pool_name
      attr_reader :networks

      attr_reader :packages
      attr_reader :templates
      attr_reader :properties

      attr_reader :num_instances
    end

    class InstanceData < Data
      attr_reader :job_name
      attr_reader :resource_pool_name
      attr_reader :index
      attr_reader :state

      attr_reader :configuration_hash
      attr_reader :template_hashes
      attr_reader :rendered_templates_archive
      attr_reader :packages

      attr_reader :dns
      attr_reader :network_assignment
      attr_reader :vm
      attr_reader :disk
    end

    class VmData < Data
      attr_reader :stemcell
      attr_reader :agent_id
    end

    class NetworkAssignmentData < Data
      attr_reader :dns
      attr_reader :gateway
      attr_reader :ip_addresses
    end

    class IpData < Data
      attr_reader :address
      attr_reader :type
    end

    class DiskData < Data
      attr_reader :disk_pool_name
      attr_reader :size
      attr_reader :cloud_properties
    end
  end
end
