require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Plan do
      subject { Plan.new(deployment_model) }

      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:deployment_model) { make_deployment('my_cloud') }

      describe '#initialize' do
        describe 'options' do
          describe 'recreate' do
            it 'is true when provided' do
              plan = Plan.new(deployment_model, recreate: true)
              expect(plan.recreate).to eq(true)
            end

            it 'defaults to false' do
              plan = Plan.new('name')
              expect(plan.recreate).to eq(false)
            end
          end

          describe 'job_rename' do
            it 'sets rename_in_progress to true' do
              plan = Plan.new(deployment_model, job_rename:{'old_name' => 'old-name', 'new_name' => 'new-name'})

              expect(plan.rename_in_progress?).to be
            end

            it 'sets rename_in_progress to false by default' do
              plan = Plan.new(deployment_model)
              expect(plan.rename_in_progress?).to eq(false)
            end
          end
        end
      end

      describe '#canonical_name' do
        it 'returns the canonical version of the name' do
          expect(Plan.new(Models::Deployment.new(name: 'Name with spaces')).canonical_name).to eq('namewithspaces')
        end
      end

      describe '#bind_model' do
        describe 'getting VM models list' do
          it 'returns a list of VMs in deployment' do
            deployment_model = make_deployment('my_cloud')
            vm_model1 = Models::Vm.make(deployment: deployment_model)
            vm_model2 = Models::Vm.make(deployment: deployment_model)

            plan = Plan.new(deployment_model)
            expect(plan.vms).to eq([vm_model1, vm_model2])
          end
        end
      end

      describe '#jobs_starting_on_deploy' do
        before { subject.add_job(job1) }
        let(:job1) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
            name: 'fake-job1-name',
            canonical_name: 'fake-job1-cname',
          })
        end

        before { subject.add_job(job2) }
        let(:job2) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
            name: 'fake-job2-name',
            canonical_name: 'fake-job2-cname',
          })
        end

        context 'when there is at least one job that runs when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

          it 'only returns jobs that start on deploy' do

            expect(subject.jobs_starting_on_deploy).to eq([job2])
          end
        end

        context 'when there are no jobs that run when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(false) }

          it 'only returns jobs that start on deploy' do
            expect(subject.jobs_starting_on_deploy).to eq([])
          end
        end
      end

      describe '#update_stemcell_references!' do
        it 'should deletes references to no longer used stemcells', pending: 'not yet tested' do
          resource_pool_spec = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
          stemcell_spec = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

          new_stemcell = Bosh::Director::Models::Stemcell.make
          old_stemcell = Bosh::Director::Models::Stemcell.make

          deployment.add_stemcell(old_stemcell)

          allow(deployment_plan).to receive(:resource_pools).and_return([resource_pool_spec])

          allow(Bosh::Director::ResourcePoolUpdater).to receive(:new).with(resource_pool_spec).and_return(double('update_step'))

          allow(resource_pool_spec).to receive(:stemcell).and_return(stemcell_spec)
          allow(stemcell_spec).to receive(:model).and_return(new_stemcell)

          update_deployment_job = Bosh::Director::Jobs::UpdateDeployment.new(manifest_file.path, nil)
          update_deployment_job.update_stemcell_references

          expect(old_stemcell.deployments).to be_empty
        end
      end

      describe '#commit!' do
        it('works', pending: 'not yet tested') { fail }
      end

      def make_deployment(name)
        Models::Deployment.make(name: name)
      end
    end
  end
end
