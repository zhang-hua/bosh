module Bosh::Director
  module DeploymentPlan
    class UpdateStep


      def initialize(base_job, event_log, resource_pools, assembler, deployment_plan, deployment, multi_job_updater)
        @base_job = base_job
        @logger = base_job.logger
        @event_log = event_log
        @resource_pools = resource_pools
        @assembler = assembler
        @deployment_plan = deployment_plan
        @deployment = deployment
        @multi_job_updater = multi_job_updater
      end

      def perform
        begin
          @logger.info('Updating deployment')
          update
          @deployment_plan.update_releases!
          @logger.info('Committing updates')
          @deployment_plan.commit!
          @logger.info('Finished updating deployment')
        ensure
          @deployment_plan.update_stemcell_references!
        end
      end

      private

      def update
        @event_log.begin_stage('Preparing DNS', 1)
        @base_job.track_and_log('Binding DNS') do
          @assembler.bind_dns
        end

        @logger.info('Deleting no longer needed VMs')
        @assembler.delete_unneeded_vms

        @logger.info('Deleting no longer needed instances')
        @assembler.delete_unneeded_instances

        @logger.info('Updating resource pools')
        @resource_pools.update
        @base_job.task_checkpoint

        @logger.info('Binding instance VMs')
        @assembler.bind_instance_vms

        @event_log.begin_stage('Preparing configuration', 1)
        @base_job.track_and_log('Binding configuration') do
          @assembler.bind_configuration
        end

        @logger.info('Updating jobs')
        @multi_job_updater.run(
          @base_job,
          @deployment_plan,
          @deployment_plan.jobs_starting_on_deploy,
        )

        @logger.info('Refilling resource pools')
        @resource_pools.refill
      end
    end
  end
end
