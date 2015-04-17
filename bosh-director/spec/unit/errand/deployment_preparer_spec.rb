require 'spec_helper'

describe Bosh::Director::Errand::DeploymentPreparer do
  subject { described_class.new(deployment_plan, job, event_log, base_job) }
  let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Plan') }
  let(:job)        { instance_double('Bosh::Director::DeploymentPlan::Job') }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log') }
  let(:base_job)   { instance_double('Bosh::Director::Jobs::BaseJob') }

  describe '#prepare_deployment' do
    it 'binds deployment with all of its present resources' do
      assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
      expect(Bosh::Director::DeploymentPlan::Assembler).to receive(:new).
        with(deployment_plan).
        and_return(assembler)

      prepare_step = instance_double('Bosh::Director::DeploymentPlan::PrepareStep')
      expect(Bosh::Director::DeploymentPlan::PrepareStep).to receive(:new).
        with(base_job, assembler).
        and_return(prepare_step)

      expect(prepare_step).to receive(:perform).with(no_args)

      compile_step = instance_double('Bosh::Director::PackageCompileStep')
      expect(Bosh::Director::PackageCompileStep).to receive(:new).
        with(base_job, deployment_plan).
        and_return(compile_step)

      expect(compile_step).to receive(:perform).with(no_args)

      subject.prepare_deployment
    end
  end

  describe '#prepare_job' do
    it 'binds unallocated vms and instance networks for given job' do
      expect(job).to receive(:bind_unallocated_vms).with(no_args)
      expect(job).to receive(:bind_instance_networks).with(no_args)

      subject.prepare_job
    end
  end
end
