require 'spec_helper'

module Bosh::Director::Jobs
  describe UpdateDeployment do
    # let(:app) { instance_double('Bosh::Director::App', blobstores: blobstores) }
    # let(:blobstores) { instance_double('Bosh::Director::Blobstores', blobstore: blobstore) }
    # let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    # before { allow(Bosh::Director::App).to receive(:instance).and_return(app) }
    #
    # describe 'Resque job class expectations' do
    #   let(:job_type) { :update_deployment }
    #   it_behaves_like 'a Resque job'
    # end
    #
    # describe 'instance methods' do
    #   let(:app) { instance_double('Bosh::Director::App', blobstores: blobstores) }
    #   let(:blobstores) { instance_double('Bosh::Director::Blobstores', blobstore: blobstore) }
    #   let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
    #   before { allow(Bosh::Director::App).to receive(:instance).and_return(app) }
    #
    #
    #
    #
    #
    #
    #   let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Plan') }
    #   let(:manifest) { double('manifest') }
    #
    #   before do
    #     Bosh::Director::Config.configure(Psych.load_file(asset('test-director-config.yml'))) #FIXME: polluting global state
    #
    #     pool1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
    #     pool2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
    #
    #     allow(deployment_plan).to receive(:name).and_return('test_deployment')
    #     allow(deployment_plan).to receive(:resource_pools).and_return([pool1, pool2])
    #
    #     update_step1 = instance_double('Bosh::Director::ResourcePoolUpdater')
    #     update_step2 = instance_double('Bosh::Director::ResourcePoolUpdater')
    #
    #     allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(pool1).and_return(update_step1)
    #     allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(pool2).and_return(update_step2)
    #
    #     allow(Bosh::Director::DeploymentPlan::Plan).to receive(:parse).and_return(deployment_plan)
    #
    #     File.open(manifest_file.path, 'w') do |f|
    #       f.write('manifest')
    #     end
    #     allow(Psych).to receive(:load).with('manifest').and_return(manifest)
    #
    #     @tmpdir = Dir.mktmpdir('base_dir')
    #
    #     allow(Bosh::Director::Config).to receive(:base_dir).and_return(@tmpdir)
    #   end
    #
    #   after do
    #     FileUtils.rm_rf(@tmpdir)
    #   end
    #
    #   describe '#initialize' do
    #     it 'parses the deployment manifest using the deployment plan, passing it the event log' do
    #       expect(Bosh::Director::DeploymentPlan::Plan).to receive(:parse).
    #         with(
    #           manifest,
    #           nil,
    #           { 'recreate' => false, 'job_states' => { }, 'job_rename' => { } },
    #           Bosh::Director::Config.event_log,
    #           Bosh::Director::Config.logger
    #         ).
    #         and_return(deployment_plan)
    #
    #       described_class.new(manifest_file.path, nil)
    #     end
    #   end
    #
    #   describe 'prepare' do
    #     it 'should prepare the deployment plan' do
    #       Bosh::Director::Models::Deployment.make(name: 'test_deployment')
    #       assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
    #       package_compiler = instance_double('Bosh::Director::PackageCompiler')
    #
    #       allow(Bosh::Director::DeploymentPlan::Assembler).to receive(:new).with(deployment_plan).and_return(assembler)
    #       update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path, nil)
    #       allow(Bosh::Director::PackageCompiler).to receive(:new).with(deployment_plan).and_return(package_compiler)
    #
    #       expect(assembler).to receive(:bind_deployment).ordered
    #       expect(assembler).to receive(:bind_releases).ordered
    #       expect(assembler).to receive(:bind_existing_deployment).ordered
    #       expect(assembler).to receive(:bind_resource_pools).ordered
    #       expect(assembler).to receive(:bind_stemcells).ordered
    #       expect(assembler).to receive(:bind_templates).ordered
    #       expect(assembler).to receive(:bind_properties).ordered
    #       expect(assembler).to receive(:bind_unallocated_vms).ordered
    #       expect(assembler).to receive(:bind_instance_networks).ordered
    #       expect(package_compiler).to receive(:compile)
    #
    #       update_deployment_job.prepare
    #
    #       check_event_log do |events|
    #         expect(events.size).to eq(18)
    #         expect(events.select { |e| e['stage'] == 'Preparing deployment' }.size).to eq(18)
    #       end
    #     end
    #   end
    #
    #   describe '#update' do
    #     it 'should update the deployment' do
    #       assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
    #       resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
    #       resource_pool_update_step =  instance_double('Bosh::Director::ResourcePoolUpdater')
    #       job =  instance_double('Bosh::Director::DeploymentPlan::Job')
    #
    #       allow(resource_pool_update_step).to receive(:extra_vm_count).and_return(2)
    #       allow(resource_pool_update_step).to receive(:outdated_idle_vm_count).and_return(3)
    #       allow(resource_pool_update_step).to receive(:bound_missing_vm_count).and_return(4)
    #       allow(resource_pool_update_step).to receive(:missing_vm_count).and_return(5)
    #
    #       allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(resource_pool).and_return(resource_pool_update_step)
    #
    #       job_update_step_factory = instance_double('Bosh::Director::JobUpdaterFactory')
    #       allow(Bosh::Director::JobUpdaterFactory).to receive(:new).with(blobstore).and_return(job_update_step_factory)
    #
    #       multi_job_update_step = instance_double('Bosh::Director::DeploymentPlan::BatchMultiJobUpdater')
    #       allow(Bosh::Director::DeploymentPlan::BatchMultiJobUpdater).to receive(:new).with(job_update_step_factory).and_return(multi_job_update_step)
    #
    #       allow(resource_pool).to receive(:name).and_return('resource_pool_name')
    #
    #       allow(job).to receive(:name).and_return('job_name')
    #
    #       allow(deployment_plan).to receive(:resource_pools).and_return([resource_pool])
    #       allow(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([job])
    #
    #       expect(assembler).to receive(:bind_dns).ordered
    #
    #       expect(assembler).to receive(:delete_unneeded_vms).ordered
    #       expect(assembler).to receive(:delete_unneeded_instances).ordered
    #
    #       expect(resource_pool_update_step).to receive(:delete_extra_vms).ordered
    #       expect(resource_pool_update_step).to receive(:delete_outdated_idle_vms).ordered
    #       expect(resource_pool_update_step).to receive(:create_bound_missing_vms).ordered
    #
    #       expect(assembler).to receive(:bind_instance_vms).ordered
    #       expect(assembler).to receive(:bind_configuration).ordered
    #
    #       expect(multi_job_update_step).to receive(:run).ordered
    #
    #       expect(resource_pool_update_step).to receive(:reserve_networks).ordered
    #       expect(resource_pool_update_step).to receive(:create_missing_vms).ordered
    #
    #       update_deployment_job = described_class.new(manifest_file.path, nil)
    #       update_deployment_job.instance_eval { @assembler = assembler }
    #       update_deployment_job.update
    #
    #       check_event_log do |events|
    #         expect(events.select { |e| e['task'] == 'Binding configuration' }.size).to eq(2)
    #       end
    #     end
    #   end

    #
    #   describe 'perform' do
    #     let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'test_deployment') }
    #
    #     let(:foo_release) { Bosh::Director::Models::Release.make(name: 'foo_release') }
    #     let(:foo_release_version) do
    #       Bosh::Director::Models::ReleaseVersion.make(release: foo_release, version: 17)
    #     end
    #
    #     let(:bar_release) { Bosh::Director::Models::Release.make(name: 'bar_release') }
    #     let(:bar_release_version) do
    #       Bosh::Director::Models::ReleaseVersion.make(release: bar_release, version: 42)
    #     end
    #
    #     let(:foo_release_spec) do
    #       instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
    #         name: 'foo',
    #         model: foo_release_version
    #       )
    #     end
    #
    #     let(:bar_release_spec) do
    #       instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
    #         name: 'bar',
    #         model: bar_release_version
    #       )
    #     end
    #
    #     let(:release_specs) { [foo_release_spec, bar_release_spec] }
    #
    #     let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }
    #     before do
    #       allow(notifier).to receive(:send_error_event)
    #       allow(notifier).to receive(:send_start_event)
    #       allow(notifier).to receive(:send_end_event)
    #
    #       allow(deployment_plan).to receive(:releases).and_return(release_specs)
    #       allow(deployment_plan).to receive(:model).and_return(deployment)
    #     end
    #
    #     let(:job) { Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path, nil) }
    #
    #     before do
    #       allow(job).to receive(:notifier).and_return(notifier)
    #     end
    #
    #     context 'when an error happens' do
    #       before do
    #         allow(job).to receive(:with_deployment_lock).and_yield
    #         allow(job).to receive(:prepare).and_raise('Expected Error')
    #       end
    #
    #       it 'sends an error event' do
    #         expect(notifier).to receive(:send_error_event)
    #
    #         begin
    #           job.perform
    #         rescue
    #         end
    #       end
    #
    #       it 're-raises the exception' do
    #         expect { job.perform }.to raise_error('Expected Error')
    #       end
    #     end
    #
    #     context 'with a cloud config' do
    #       let!(:iaas_config) { Bosh::Director::Models::IaasConfig.create(properties: '--\nfoo: bar') }
    #       let(:job) { Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path, iaas_config.id) }
    #
    #       it 'should do a basic update' do
    #         expect(job).to receive(:with_deployment_lock).with(deployment_plan).and_yield.ordered
    #         expect(notifier).to receive(:send_start_event).ordered
    #         expect(job).to receive(:prepare).ordered
    #         expect(job).to receive(:update).ordered
    #         expect(job).to receive(:with_release_locks).with(deployment_plan).and_yield.ordered
    #         expect(notifier).to receive(:send_end_event).ordered
    #         expect(job).to receive(:update_stemcell_references).ordered
    #
    #         expect(deployment).to receive(:add_release_version).with(foo_release_version)
    #         expect(deployment).to receive(:add_release_version).with(bar_release_version)
    #
    #         expect(deployment.iaas_config).to be_nil
    #
    #         expect(job.perform).to eq('/deployments/test_deployment')
    #
    #         deployment.refresh
    #         expect(deployment.manifest).to eq('manifest')
    #         expect(deployment.iaas_config).to eq(iaas_config)
    #       end
    #     end
    #
    #     context 'without a cloud config' do
    #       let(:job) { Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path, nil) }
    #
    #       it 'should do a basic update of everything but the cloud config' do
    #         expect(job).to receive(:with_deployment_lock).with(deployment_plan).and_yield.ordered
    #         expect(notifier).to receive(:send_start_event).ordered
    #         expect(job).to receive(:prepare).ordered
    #         expect(job).to receive(:update).ordered
    #         expect(job).to receive(:with_release_locks).with(deployment_plan).and_yield.ordered
    #         expect(notifier).to receive(:send_end_event).ordered
    #         expect(job).to receive(:update_stemcell_references).ordered
    #
    #         expect(deployment).to receive(:add_release_version).with(foo_release_version)
    #         expect(deployment).to receive(:add_release_version).with(bar_release_version)
    #
    #         expect(job.perform).to eq('/deployments/test_deployment')
    #
    #         deployment.refresh
    #         expect(deployment.manifest).to eq('manifest')
    #         expect(deployment.iaas_config).to be_nil
    #       end
    #     end
    #   end
    # end


    subject(:job) { UpdateDeployment.new(manifest_path) }

    let(:config) { Bosh::Director::Config.load_file(asset('test-director-config.yml'))}
    let(:blobstores) { instance_double('Bosh::Director::Blobstores', blobstore: blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }


    let(:directory) { Support::FileHelpers::DeploymentDirectory.new }
    let(:iaas_config_id) { nil }
    let(:manifest_path) { directory.add_file('deployment.yml', manifest_content) }
    let(:manifest_content) do
      <<-MANIFEST
---
name: deployment-name
release:
  name: release-name
  version: 1
networks:
- name: network-name
  subnets: []
compilation:
  workers: 1
  network: network-name
  cloud_properties: {}
update:
  max_in_flight: 10
  canaries: 0
  canary_watch_time: 1000
  update_watch_time: 1000
resource_pools:
- name: my-pool
  cloud_properties: {}
  stemcell: {name: x, version: 1}
  network: network-name
      MANIFEST
    end

    before do
      Bosh::Director::App.new(config)
    end

    describe '#perform' do
      let(:prepare_step) { instance_double('Bosh::Director::DeploymentPlan::PrepareStep') }
      let(:compile_step) { instance_double('Bosh::Director::PackageCompileStep') }
      let(:update_step) { instance_double('Bosh::Director::DeploymentPlan::UpdateStep') }
      let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }

      before do
        allow(Bosh::Director::DeploymentPlan::PrepareStep).to receive(:new)
            .and_return(prepare_step)
        allow(Bosh::Director::PackageCompileStep).to receive(:new)
            .and_return(compile_step)
        allow(Bosh::Director::DeploymentPlan::UpdateStep).to receive(:new)
            .and_return(update_step)
        allow(Bosh::Director::DeploymentPlan::Notifier).to receive(:new)
            .and_return(notifier)
      end

      describe "deployment_plan" do

        context "when the manifest if valid" do
          it "creates a plan from the proper manifest file" do
            plan = job.deployment_plan
            expect(plan.name).to eq("deployment-name")
          end
        end

        context "when the manifest is invalid" do
          let(:manifest_content) { strip_heredoc(<<-MANIFEST) }
            ---
            name: deployment-name
          MANIFEST

          it "creates a plan from the proper manifest file" do
            expect{ job.deployment_plan }.to raise_error(Bosh::Director::ValidationMissingField)
          end
        end

        context "when the iaas_config_id is not specified" do

        end

        context "when the iaas_config_id is specified" do
          let(:manifest_content) do
            <<-MANIFEST
---
name: deployment-name
release:
  name: release-name
  version: 1
compilation:
  workers: 1
  network: other-network
  cloud_properties: {}
update:
  max_in_flight: 10
  canaries: 0
  canary_watch_time: 1000
  update_watch_time: 1000
            MANIFEST
          end

          let(:iaas_config_content) do
            <<-MANIFEST
---
networks:
- name: other-network
  subnets: []
resource_pools:
- name: my-pool
  cloud_properties: {}
  stemcell: {name: x, version: 1}
  network: other-network
            MANIFEST
          end

          let(:iaas_config_id) { iaas_config_record.id }
          let!(:iaas_config_record) { Bosh::Director::Models::IaasConfig.create(properties: iaas_config_content) }

          it "loads the config from the database" do
            expect(job.deployment_plan.resource_pools.map(&:name)).to eq(['my-pool'])
          end
        end
      end

      context 'without a cloud config' do
        context 'when all tasks complete' do
          before do
            expect(job).to receive(:with_deployment_lock).and_yield.ordered
            expect(notifier).to receive(:send_start_event).ordered
            expect(prepare_step).to receive(:perform).ordered
            expect(compile_step).to receive(:perform).ordered
            expect(update_step).to receive(:perform).ordered
            expect(notifier).to receive(:send_end_event).ordered
          end

          it 'performs an update' do
            expect(job.perform).to eq("/deployments/deployment-name")
          end

          it 'cleans up the temporary manifest' do
            job.perform
            expect(File.exist? manifest_path).to be_falsey
          end
        end

        context 'when the first task fails' do
          before do
            expect(job).to receive(:with_deployment_lock).and_yield.ordered
            expect(notifier).to receive(:send_start_event).ordered
            expect(prepare_step).to receive(:perform).and_raise(Exception).ordered
          end

          it 'does not compile or update' do
            expect {
              job.perform
            }.to raise_error(Exception)
          end

          it 'cleans up the temporary manifest' do
            expect {
              job.perform
            }.to raise_error(Exception)
            expect(File.exist? manifest_path).to be_falsey
          end
        end
      end
    end
  end
end
