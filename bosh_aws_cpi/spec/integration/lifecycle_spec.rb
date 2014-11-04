require 'spec_helper'
require 'bosh/cpi/compatibility_helpers/delete_vm'
require 'tempfile'
require 'logger'
require 'cloud'

describe Bosh::AwsCloud::Cloud do
  before(:all) do
    @access_key_id     = ENV['BOSH_AWS_ACCESS_KEY_ID']       || raise("Missing BOSH_AWS_ACCESS_KEY_ID")
    @secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']   || raise("Missing BOSH_AWS_SECRET_ACCESS_KEY")
    @subnet_id         = ENV['BOSH_AWS_SUBNET_ID']           || raise("Missing BOSH_AWS_SUBNET_ID")
    @manual_ip         = ENV['BOSH_AWS_LIFECYCLE_MANUAL_IP'] || raise("Missing BOSH_AWS_LIFECYCLE_MANUAL_IP")
  end

  let(:instance_type) { ENV.fetch('BOSH_AWS_INSTANCE_TYPE', 't2.small') }
  let(:ami) { ENV.fetch('BOSH_AWS_IMAGE_ID', 'ami-b66ed3de') }

  before { Bosh::Registry::Client.stub(new: double('registry').as_null_object) }

  # Use subject-bang because AWS SDK needs to be reconfigured
  # with a current test's logger before new AWS::EC2 object is created.
  # Reconfiguration happens via `AWS.config`.
  subject!(:cpi) do
    described_class.new(
      'aws' => {
        'region' => 'us-east-1',
        'default_key_name' => 'bosh',
        'fast_path_delete' => 'yes',
        'access_key_id' => @access_key_id,
        'secret_access_key' => @secret_access_key,
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end

  before do
    AWS::EC2.new(
      access_key_id:     @access_key_id,
      secret_access_key: @secret_access_key,
    ).instances.tagged('delete_me').each(&:terminate)
  end

  before do
    Bosh::Clouds::Config.configure(
      double('delegate', task_checkpoint: nil, logger: Logger.new(STDOUT)))
  end

  before { Bosh::Clouds::Config.stub(logger: logger) }
  let(:logger) { Logger.new(STDERR) }

  before { @instance_id = nil }
  after  { cpi.delete_vm(@instance_id) if @instance_id }

  before { @volume_id = nil }
  after  { cpi.delete_disk(@volume_id) if @volume_id }

  extend Bosh::Cpi::CompatibilityHelpers

  describe 'ec2' do
    describe 'deleting vms with persistent disk' do
      let(:vip) { '192.168.0.0' } #TODO: get real vip
      let(:network_spec) do
        {
          'static' => {
            'type' => 'vip',
            'ip' => vip,
            'cloud_properties' => {}
          }
        }
      end

      let(:options) do
        {
          user_known_hosts_file: %w[/dev/null],
          keys: ['~/workspace/dolores/config/id_rsa_bosh'],
          password: 'sudo-pass', #TODO: get password from ami!
        }
      end

      def ssh(host, user, command, options = {})
        options = options.dup
        output = nil
        put("--> ssh: #{user}@#{host} #{command.inspect}")
        put("--> ssh options: #{options.inspect}")

        Net::SSH.start(host, user, options) do |ssh|
          output = ssh.exec!(command).to_s
        end

        put("--> ssh output: #{output.inspect}")
        output
      end

      def ssh_sudo(host, user, command, options)
        if options[:password].nil?
          raise 'Need to set sudo :password'
        end
        ssh(host, user, "echo #{options[:password]} | sudo -p '' -S #{command}", options)
      end

      def mount_persistent_disk(instance_id)
        settings = cpi.registry.read_settings(instance_id)
        device_name = settings['disks']['persistent'].first
        ssh_sudo(vip, 'ubuntu', "mkdir -p /tmp/persistent-disk && mount #{device_name} /tmp/persistent-disk", options)
      end

      describe '' do
        @instance_id = cpi.create_vm(
          'fake-agent-id',
          ami,
          { 'instance_type' => instance_type },
          network_spec,
          [],
          {}
        )
        expect(@instance_id).not_to be_nil

        @volume_id = cpi.create_disk(2048, {}, @instance_id)
        expect(@volume_id).not_to be_nil

        cpi.attach_disk(@instance_id, @volume_id)

        mount_persistent_disk(@instance_id)

        1.times do |i|
          cpi.delete_vm(@instance_id)
          @instance_id = cpi.create_vm(
            nil,
            ami,
            { 'instance_type' => instance_type },
            network_spec,
            [],
            {}
          )
          cpi.attach_disk(@instance_id, @volume_id)
          mount_persistent_disk(@instance_id)
        end
      end
    end
  end
end
