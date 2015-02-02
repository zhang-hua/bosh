require 'spec_helper'

puts "For stack trace, do this: kill -TTIN #{Process.pid}"
trap 'TTIN' do
  Thread.list.each do |thread|
    puts "Thread TID-#{thread.object_id.to_s(36)}"
    puts thread.backtrace.join("\n")
  end
end

describe Bosh::Director::Jobs::UpdateDeployment do
  let(:app) { instance_double('Bosh::Director::App', blobstores: blobstores) }
  let(:blobstores) { instance_double('Bosh::Director::Blobstores', blobstore: blobstore) }
  let(:blobstore) { instance_double('Bosh::Blobstore::Client') }
  before { allow(Bosh::Director::App).to receive(:instance).and_return(app) }

  describe 'Resque job class expectations' do
    let(:job_type) { :update_deployment }
    it_behaves_like 'a Resque job'
  end

  context 'without mocking the entire freaking world away' do
    let(:manifest) { <<-YAML }
      name: fake
      releases:
      - { name: mysql, version: 1 }
      compilation: { workers: 1, network: default }
      update: { canaries: 1, max_in_flight: 1, canary_watch_time: 100, update_watch_time: 100 }
      networks:
      - { name: default, subnets: [{ range: 10.10.0.0/24, gateway: 10.10.0.1, dns: [10.10.0.2] }] }
      resource_pools:
      - { name: pool0, stemcell: { name: a-stemcell, version: 123 }, network: default }
      jobs:
      - name: cluster
        templates:
        - name: mysqld
          release: mysql
        resource_pool: pool0
        instances: 1
        networks: [{ name: default }]
        properties:
          username: root
    YAML

    let(:manifest_file) { Tempfile.new('manifest').tap {|t| File.write(t.path, manifest)} }
    after { manifest_file.delete }

    before do
      Bosh::Director::Config.cloud_options = { 'external_cpi' => { 'cpi_path' => 'fake-cpi', 'enabled' => true } }
      Bosh::Clouds::Config.configure(double(:delegate, logger: Logging::Logger.new))
      release = Bosh::Director::Models::Release.create(name: 'mysql')
      release_version = Bosh::Director::Models::ReleaseVersion.new(version: '1')
      release.add_version(release_version)
      release.save
      template = Bosh::Director::Models::Template.create(
        name: 'mysqld', version: '1', blobstore_id: '1234', sha1: '4321',
        package_names_json: '[]', release_id:  release.id
      )
      release_version.add_template(template)
      Bosh::Director::Models::Stemcell.create(name: 'a-stemcell', version: '123', cid: 'abc')
      Bosh::Director::Models::Dns::Domain.create(name: 'mydomain', type: 'xxx')
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(false)
      allow(File).to receive(:executable?).with('fake-cpi').and_return(true)
      allow(Open3).to receive(:capture3).and_return(['{"result": "", "log": "", "error": null}', 'err', 0])
      allow_any_instance_of(Bosh::Clouds::ExternalCpi).to receive(:save_cpi_log) { |_, *args| p *args }
      # allow_any_instance_of(Bosh::Director::AgentClient).to receive(:ping)
      allow_any_instance_of(Bosh::Director::DeploymentPlan::Notifier).to receive_messages(
        :send_start_event => nil, :send_end_event => nil, :send_error_event => nil)
      allow_any_instance_of(Bosh::Director::JobRenderer).to receive(:render_job_instances)
      allow_any_instance_of(Bosh::Director::DeploymentPlan::BatchMultiJobUpdater).to receive(:run)
      nats_rpc = double(:nats_rpc)
      allow(Bosh::Director::Config).to receive(:nats_rpc).and_return(nats_rpc)
      allow(nats_rpc).to receive(:send_request) do |message_name, *args, &block|
        p "send_request", message_name, args
        block.call({"encrypted_data" => "foo"})
      end
    end
    subject(:command) { Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path) }

    it 'takes a manifest and generates config' do
      called_with_instances = nil
      allow_any_instance_of(Bosh::Director::DeploymentPlan::InstanceVmBinder).to receive(:bind_instance_vms) do |_, instances|
        called_with_instances = instances
      end
      command.perform
      expect(called_with_instances.size).to eq(1)
      instance = called_with_instances.first
      expect(instance.job.name).to eq('cluster')
      expect(instance.job.all_properties).to eq({'username' => 'root'})
    end
  end

  describe 'instance methods' do
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
    before do
      pool1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
      pool2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')

      allow(deployment_plan).to receive(:name).and_return('test_deployment')
      allow(deployment_plan).to receive(:resource_pools).and_return([pool1, pool2])

      updater1 = instance_double('Bosh::Director::ResourcePoolUpdater')
      updater2 = instance_double('Bosh::Director::ResourcePoolUpdater')

      allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(pool1).and_return(updater1)
      allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(pool2).and_return(updater2)

      allow(Bosh::Director::DeploymentPlan::Planner).to receive(:parse).and_return(deployment_plan)
    end

    let(:manifest) { double('manifest') }
    let(:manifest_file) { Tempfile.new('manifest') }
    before do
      File.open(manifest_file.path, 'w') do |f|
        f.write('manifest')
      end
      allow(Psych).to receive(:load).with('manifest').and_return(manifest)
    end

    before do
      @tmpdir = Dir.mktmpdir('base_dir')

      allow(Bosh::Director::Config).to receive(:base_dir).and_return(@tmpdir)
    end

    after do
      FileUtils.rm_rf(@tmpdir)
    end

    describe '#initialize' do
      it 'parses the deployment manifest using the deployment plan, passing it the event log' do
        expect(Bosh::Director::DeploymentPlan::Planner).to receive(:parse).
          with(
            manifest,
            { 'recreate' => false, 'job_states' => { }, 'job_rename' => { } },
            Bosh::Director::Config.event_log,
            Bosh::Director::Config.logger
          ).
          and_return(deployment_plan)

        described_class.new(manifest_file.path)
      end
    end

    describe 'prepare' do
      it 'should prepare the deployment plan' do
        Bosh::Director::Models::Deployment.make(name: 'test_deployment')
        assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
        package_compiler = instance_double('Bosh::Director::PackageCompiler')

        allow(Bosh::Director::DeploymentPlan::Assembler).to receive(:new).with(deployment_plan).and_return(assembler)
        update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path)
        allow(Bosh::Director::PackageCompiler).to receive(:new).with(deployment_plan).and_return(package_compiler)

        expect(assembler).to receive(:bind_deployment).ordered
        expect(assembler).to receive(:bind_releases).ordered
        expect(assembler).to receive(:bind_existing_deployment).ordered
        expect(assembler).to receive(:bind_resource_pools).ordered
        expect(assembler).to receive(:bind_stemcells).ordered
        expect(assembler).to receive(:bind_templates).ordered
        expect(assembler).to receive(:bind_properties).ordered
        expect(assembler).to receive(:bind_unallocated_vms).ordered
        expect(assembler).to receive(:bind_instance_networks).ordered
        expect(package_compiler).to receive(:compile)

        update_deployment_job.prepare

        check_event_log do |events|
          expect(events.size).to eq(18)
          expect(events.select { |e| e['stage'] == 'Preparing deployment' }.size).to eq(18)
        end
      end
    end

    describe '#update' do
      it 'should update the deployment' do
        assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
        resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        resource_pool_updater =  instance_double('Bosh::Director::ResourcePoolUpdater')
        job =  instance_double('Bosh::Director::DeploymentPlan::Job')

        allow(resource_pool_updater).to receive(:extra_vm_count).and_return(2)
        allow(resource_pool_updater).to receive(:outdated_idle_vm_count).and_return(3)
        allow(resource_pool_updater).to receive(:bound_missing_vm_count).and_return(4)
        allow(resource_pool_updater).to receive(:missing_vm_count).and_return(5)

        allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(resource_pool).and_return(resource_pool_updater)

        job_updater_factory = instance_double('Bosh::Director::JobUpdaterFactory')
        allow(Bosh::Director::JobUpdaterFactory).to receive(:new).with(blobstore).and_return(job_updater_factory)

        multi_job_updater = instance_double('Bosh::Director::DeploymentPlan::BatchMultiJobUpdater')
        allow(Bosh::Director::DeploymentPlan::BatchMultiJobUpdater).to receive(:new).with(job_updater_factory).and_return(multi_job_updater)

        allow(resource_pool).to receive(:name).and_return('resource_pool_name')

        allow(job).to receive(:name).and_return('job_name')

        allow(deployment_plan).to receive(:resource_pools).and_return([resource_pool])
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([job])

        expect(assembler).to receive(:bind_dns).ordered

        expect(assembler).to receive(:delete_unneeded_vms).ordered
        expect(assembler).to receive(:delete_unneeded_instances).ordered

        expect(resource_pool_updater).to receive(:delete_extra_vms).ordered
        expect(resource_pool_updater).to receive(:delete_outdated_idle_vms).ordered
        expect(resource_pool_updater).to receive(:create_bound_missing_vms).ordered

        expect(assembler).to receive(:bind_instance_vms).ordered
        expect(assembler).to receive(:bind_configuration).ordered

        expect(multi_job_updater).to receive(:run).ordered

        expect(resource_pool_updater).to receive(:reserve_networks).ordered
        expect(resource_pool_updater).to receive(:create_missing_vms).ordered

        update_deployment_job = described_class.new(manifest_file.path)
        update_deployment_job.instance_eval { @assembler = assembler }
        update_deployment_job.update

        check_event_log do |events|
          expect(events.select { |e| e['task'] == 'Binding configuration' }.size).to eq(2)
        end
      end
    end

    describe 'update_stemcell_references' do
      it 'should delete references to no longer used stemcells' do
        deployment = Bosh::Director::Models::Deployment.make

        resource_pool_spec = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        stemcell_spec = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

        new_stemcell = Bosh::Director::Models::Stemcell.make
        old_stemcell = Bosh::Director::Models::Stemcell.make

        deployment.add_stemcell(old_stemcell)

        allow(deployment_plan).to receive(:model).and_return(deployment)
        allow(deployment_plan).to receive(:resource_pools).and_return([resource_pool_spec])

        allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(resource_pool_spec).and_return(double('updater'))

        allow(resource_pool_spec).to receive(:stemcell).and_return(stemcell_spec)
        allow(stemcell_spec).to receive(:model).and_return(new_stemcell)

        update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path)
        update_deployment_job.update_stemcell_references

        expect(old_stemcell.deployments).to be_empty
      end
    end

    describe 'perform' do
      let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'test_deployment') }

      let(:foo_release) { Bosh::Director::Models::Release.make(name: 'foo_release') }
      let(:foo_release_version) do
        Bosh::Director::Models::ReleaseVersion.make(release: foo_release, version: 17)
      end

      let(:bar_release) { Bosh::Director::Models::Release.make(name: 'bar_release') }
      let(:bar_release_version) do
        Bosh::Director::Models::ReleaseVersion.make(release: bar_release, version: 42)
      end

      let(:foo_release_spec) do
        instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
          name: 'foo',
          model: foo_release_version
        )
      end

      let(:bar_release_spec) do
        instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion',
          name: 'bar',
          model: bar_release_version
        )
      end

      let(:release_specs) { [foo_release_spec, bar_release_spec] }

      let(:notifier) { instance_double('Bosh::Director::DeploymentPlan::Notifier') }
      before do
        allow(notifier).to receive(:send_error_event)
        allow(notifier).to receive(:send_start_event)
        allow(notifier).to receive(:send_end_event)
      end

      before do
        allow(deployment_plan).to receive(:releases).and_return(release_specs)
        allow(deployment_plan).to receive(:model).and_return(deployment)
      end

      let(:job) { Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path) }
      before do
        allow(job).to receive(:notifier).and_return(notifier)
      end

      context 'when an error happens' do
        before do
          allow(job).to receive(:with_deployment_lock).and_yield
          allow(job).to receive(:prepare).and_raise('Expected Error')
        end

        it 'sends an error event' do
          expect(notifier).to receive(:send_error_event)

          begin
            job.perform
          rescue
          end
        end

        it 're-raises the exception' do
          expect { job.perform }.to raise_error('Expected Error')
        end
      end

      it 'should do a basic update' do
        expect(job).to receive(:with_deployment_lock).with(deployment_plan).and_yield.ordered
        expect(notifier).to receive(:send_start_event).ordered
        expect(job).to receive(:prepare).ordered
        expect(job).to receive(:update).ordered
        expect(job).to receive(:with_release_locks).with(deployment_plan).and_yield.ordered
        expect(notifier).to receive(:send_end_event).ordered
        expect(job).to receive(:update_stemcell_references).ordered

        expect(deployment).to receive(:add_release_version).with(foo_release_version)
        expect(deployment).to receive(:add_release_version).with(bar_release_version)

        expect(job.perform).to eq('/deployments/test_deployment')

        deployment.refresh
        expect(deployment.manifest).to eq('manifest')
      end
    end
  end
end
