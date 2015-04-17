module Bosh::Director
  # Encapsulates essential director data structures retrieved
  # from the deployment manifest and the running environment.
  module DeploymentPlan
    class Plan
      private
      class Validator
        include ValidationHelper
      end
    end

    class Plan
      include DnsHelper
      include ValidationHelper
      include LockHelper

      attr_reader :canonical_name
      attr_reader :model
      attr_reader :properties
      attr_reader :compilation
      attr_reader :update
      attr_reader :jobs
      attr_reader :unneeded_instances
      attr_reader :unneeded_vms
      attr_accessor :dns_domain
      attr_reader :job_rename
      attr_reader :job_states
      attr_reader :recreate

      def self.from_manifest(deployment_manifest, options = {})
        validator = Validator.new

        iaas_manifest = {}
        iaas_config = Bosh::Director::Models::IaasConfig.latest
        deployment_model = Bosh::Director::Models::Deployment.find_or_initialize_by_manifest(deployment_manifest)
        if iaas_config.nil?
          iaas_manifest = Bosh::Director::Manifests::IaasManifest.from_deployment_manifest(deployment_manifest)
        else
          iaas_manifest = iaas_config.cleaned_manifest
          deployment_model.iaas_config = iaas_config
        end

        plan = Plan.new(
          deployment_model,
          iaas_manifest,
          job_states: validator.safe_property(options, 'job_states', :class => Hash, :default => {}),
          job_rename: validator.safe_property(options, 'job_rename', :class => Hash, :default => {}),
          recreate: (!!options['recreate']),
        )
        plan.setup!(Config.event_log, Config.logger)

        plan
      end

      def initialize(model, iaas_manifest, job_states:{}, job_rename: {}, recreate: false)
        @model = model
        @iaas_manifest = iaas_manifest
        @properties = {}
        @releases = {}
        @networks = {}
        @networks_canonical_name_index = Set.new

        @resource_pools = {}
        @disk_pools = {}

        @jobs = []
        @job_states = job_states
        @jobs_name_index = {}
        @jobs_canonical_name_index = Set.new

        @unneeded_vms = []
        @unneeded_instances = []
        @dns_domain = nil

        @job_rename = job_rename
        @recreate = recreate
      end

      def setup!(event_log, logger)
        # Setup from cloud manifest
        iaas_manifest = @iaas_manifest

        iaas_manifest['disk_pools'].each do |disk_pool|
          add_disk_pool(DiskPool.parse(disk_pool))
        end unless iaas_manifest['disk_pools'].nil?

        iaas_manifest['networks'].each do |network_spec|
          case network_spec['type']
            when 'manual'
              network = ManualNetwork.new(self, network_spec)
            when 'dynamic'
              network = DynamicNetwork.new(self, network_spec)
            when 'vip'
              network = VipNetwork.new(self, network_spec)
            when ''
          end

          add_network(network)
        end

        iaas_manifest['resource_pools'].each do |rp_spec|
          add_resource_pool(ResourcePool.new(self, rp_spec, logger))
        end

        @compilation = CompilationConfig.new(self, iaas_manifest['compilation'])

        # Setup from deployment manifest

        deployment_manifest = @model.deployment_manifest

        @properties = deployment_manifest['properties']
        @update = UpdateConfig.new(deployment_manifest['update'])

        deployment_manifest['releases'].each do |release_spec|
          add_release(ReleaseVersion.new(self, release_spec))
        end
        deployment_manifest['jobs'].map do |job_spec|
          state_overrides = @job_states[job_spec['name']]
          if state_overrides
            job_spec.recursive_merge!(state_overrides)
          end

          add_job(Job.parse(self, job_spec, event_log, logger))
        end

        @model.save
      end

      def name
        @model.name
      end

      def properties
        @model.deployment_manifest['properties']
      end

      def canonical_name
        @model.canonical_name
      end

      def update_stemcell_references!
        current_stemcell_models = Set.new
        resource_pools.each do |resource_pool|
          current_stemcell_models << resource_pool.stemcell.model
        end

        @model.stemcells.each do |stemcell_model|
          unless current_stemcell_models.include?(stemcell_model)
            stemcell_model.remove_deployment(@model)
          end
        end
      end

      def update_releases!
        with_release_locks(self) do
          @model.db.transaction do
            @model.remove_all_release_versions
            # Now we know that deployment has succeeded and can remove
            # previous partial deployments release version references
            # to be able to delete these release versions later.
            releases.each do |release|
              @model.add_release_version(release.model)
            end
          end
        end
      end

      def commit!
        @model.save
      end

      def vms
        @model.vms
      end

      def networks
        @networks.values
      end

      def network(name)
        @iaas.network(name)
      end

      def resource_pools
        @resource_pools.values
      end

      def resource_pool(name)
        @resource_pools[name]
      end

      def disk_pools
        @disk_pools.values
      end

      def disk_pool(name)
        @disk_pools[name]
      end

      def releases
        @releases.values
      end

      def release(name)
        @releases[name]
      end

      def delete_vm(vm)
        @unneeded_vms << vm
      end

      def delete_instance(instance)
        if @jobs_name_index.has_key?(instance.job)
          @jobs_name_index[instance.job].unneeded_instances << instance
        else
          @unneeded_instances << instance
        end
      end

      def job(name)
        @jobs_name_index[name]
      end

      def jobs_starting_on_deploy
        @jobs.select(&:starts_on_deploy?)
      end

      def rename_in_progress?
        !!(@job_rename['old_name'] && @job_rename['new_name'])
      end

      #TODO: all of this should be replaced with constructor args.
      def add_job(job)
        if rename_in_progress? && @job_rename['old_name'] == job.name
          raise DeploymentRenamedJobNameStillUsed,
            "Renamed job `#{job.name}' is still referenced in " +
              'deployment manifest'
        end

        if @jobs_canonical_name_index.include?(job.canonical_name)
          raise DeploymentCanonicalJobNameTaken,
            "Invalid job name `#{job.name}', canonical name already taken"
        end

        @jobs << job
        @jobs_name_index[job.name] = job
        @jobs_canonical_name_index << job.canonical_name
      end

      def add_release(release)
        if @releases.has_key?(release.name)
          raise DeploymentDuplicateReleaseName,
            "Duplicate release name `#{release.name}'"
        end
        @releases[release.name] = release
      end

      def add_disk_pool(disk_pool)
        if @disk_pools[disk_pool.name]
          raise DeploymentDuplicateDiskPoolName,
            "Duplicate disk pool name `#{disk_pool.name}'"
        end
        @disk_pools[disk_pool.name] = disk_pool
      end

      def add_resource_pool(resource_pool)
        if @resource_pools[resource_pool.name]
          raise DeploymentDuplicateResourcePoolName,
            "Duplicate resource pool name `#{resource_pool.name}'"
        end
        @resource_pools[resource_pool.name] = resource_pool
      end

      def add_network(network)
        if @networks_canonical_name_index.include?(network.canonical_name)
          raise DeploymentCanonicalNetworkNameTaken,
            "Invalid network name `#{network.name}', " +
              'canonical name already taken'
        end

        @networks[network.name] = network
        @networks_canonical_name_index << network.canonical_name
      end
    end
  end
end
