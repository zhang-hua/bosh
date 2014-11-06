require 'spec_helper'
require 'bosh/dev/download_adapter'
require 'bosh/dev/local_download_adapter'
require 'bosh/dev/promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_branch_merger'
require 'open3'
require 'bosh/dev/command_helper'
require 'fakes3'

describe 'artifact promotion', type: :integration do
  def exec_cmd(cmd)
    logger.info("Executing: #{cmd}")
    stdout, stderr, status = Open3.capture3(cmd)
    raise "Failed executing '#{cmd}'\nSTDOUT: '#{stdout}', \nSTDERR: '#{stderr}'" unless status.success?
    [stdout, stderr, status]
  end

  let(:build_number) { '0000' }
  let(:download_adapter) { instance_double('Bosh::Dev::LocalDownloadAdapter') }

  let(:config_path) { File.expand_path(File.join(File.dirname(__FILE__),'local_s3_cfg')) }
  let(:s3cmd) { "s3cmd --config #{config_path}" }
  before do
    stdout, _, _ = exec_cmd('which s3cmd')
    raise 'Please install s3cmd' if stdout.empty?
  end

  let!(:fake_s3_server) { FakeS3::Server.new('0.0.0.0', 12345, file_store, 's3.amazonaws.com') }
  let(:file_store_path) { Dir.mktmpdir('artifact_promotion_s3_store') }
  let(:file_store) { FileStore.new(File.expand_path(file_store_path)) }
  before do
    Thread.new { fake_s3_server.serve }
  end

  after do
    fake_s3_server.shutdown
    FileUtils.rm_rf(file_store_path)
  end

  let!(:workspace_path) { Dir.mktmpdir('promote_test_workspace') }
  after { FileUtils.rm_rf(workspace_path) }

  describe '#promoted?' do
    let(:bucket) { 'bosh-jenkins-artifacts' }
    subject(:build) { Bosh::Dev::Build.new(build_number, download_adapter, logger, bucket) }

    before do
      # create production bucket
      exec_cmd("#{s3cmd} mb s3://#{bucket}")
    end

    def publish_pipeline_artifacts
      Dir.chdir(workspace_path) do
        # put release tarball in s3 production bucket
        release = instance_double('Bosh::Dev::BoshRelease', final_tarball_path: File.join('tmp', 'bosh-0000.tgz'))
        File.write(stemcell.path, release.final_tarball_path)
        build.upload_release(release, final=true)

        # put stemcell (build & latest) tarballs in s3 production bucket
        [
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-aws-xen-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-vsphere-esxi-ubuntu-trusty-go_agent.tgz'), infrastructure: 'vsphere'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-hvm-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-hvm-centos-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-vsphere-esxi-centos-go_agent.tgz'), infrastructure: 'vsphere'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-aws-xen-centos-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-openstack-kvm-centos-go_agent.tgz'), infrastructure: 'openstack'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-openstack-kvm-ubuntu-trusty-go_agent.tgz'), infrastructure: 'openstack'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-centos-go_agent.tgz'), infrastructure: 'aws'),
        ].each do |stemcell|
          File.write(stemcell.path, 'some content')
          build.upload_stemcell(stemcell, final=true)
        end

        # put gems in rubygems
        allow(GemArtifact).to receive(:new).and_return(instance_double('Bosh::Dev::GemArtifact', promote: nil, promoted?: true))
      end
    end

    it 'returns true when all build artifacts have been published' do
      expect(build.promoted?).to be(false)
      publish_pipeline_artifacts
      expect(build.promoted?).to be(true)
    end
  end

  describe '#promote' do
    let(:bucket) { 'bosh-ci-pipeline' }
    subject(:build) { Bosh::Dev::Build.new(build_number, download_adapter, logger, bucket) }

    before do
      # create pipeline bucket
      exec_cmd("#{s3cmd} mb s3://#{bucket}")

      Dir.chdir(workspace_path) do
        # put release tarball in s3 pipeline bucket
        release = instance_double('Bosh::Dev::BoshRelease', final_tarball_path: File.join('tmp', 'bosh-0000.tgz'))
        File.write(stemcell.path, release.final_tarball_path)
        build.upload_release(release)

        # put stemcell (build & latest) tarballs in s3 pipeline bucket
        [
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-aws-xen-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-vsphere-esxi-ubuntu-trusty-go_agent.tgz'), infrastructure: 'vsphere'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-hvm-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-hvm-centos-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-ubuntu-trusty-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-vsphere-esxi-centos-go_agent.tgz'), infrastructure: 'vsphere'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-aws-xen-centos-go_agent.tgz'), infrastructure: 'aws'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-openstack-kvm-centos-go_agent.tgz'), infrastructure: 'openstack'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'bosh-stemcell-0000-openstack-kvm-ubuntu-trusty-go_agent.tgz'), infrastructure: 'openstack'),
          instance_double('Bosh::Stemcell::Archive', path: File.join('tmp', 'light-bosh-stemcell-0000-aws-xen-centos-go_agent.tgz'), infrastructure: 'aws'),
        ].each do |stemcell|
          File.write(stemcell.path, 'some content')
          build.upload_stemcell(stemcell)
        end

        #put gems in s3 pipeline bucket
        Dir.mkdir('gems')
        %w(
          agent_client
          blobstore_client
          bosh-core
          bosh-stemcell
          bosh-template
          bosh_aws_cpi
          bosh_cli
          bosh_cli_plugin_aws
          bosh_cli_plugin_micro
          bosh_common
          bosh_cpi
          bosh_openstack_cpi
          bosh-registry
          bosh_vsphere_cpi
          bosh_warden_cpi
          bosh-director
          bosh-director-core
          bosh-monitor
          bosh-release
          simple_blobstore_server
        ).each do |component|
          File.write(File.join('gems', "#{component}-1.0000.0.gem"), 'some content')
        end
        build.upload_gems('gems', 'gems')
      end
    end

    it 'publishes all the build artifacts' do
      allow(GemArtifact).to receive(:new).and_return(instance_double('Bosh::Dev::GemArtifact', promote: nil, promoted?: false))
      expect(build.promoted?).to be(false)
      build.promote
      allow(GemArtifact).to receive(:new).and_return(instance_double('Bosh::Dev::GemArtifact', promote: nil, promoted?: true))
      expect(build.promoted?).to be(true)
    end
  end
end
