require 'spec_helper'
require 'bosh_agent/infrastructure/openstack'

describe Bosh::Agent::Infrastructure::Openstack::Settings do
  let(:subject) { described_class.new }
  let(:registry) { Bosh::Agent::Infrastructure::Openstack::Registry }

  describe :load_settings do
    let(:settings) do
      {
        vm: { name: 'server-name' },
        agent_id: 'agent-id',
        networks: { default: { type: 'dynamic' } },
        disks: { system: '/dev/xvda', persistent: {} }
      }
    end
    let(:openssh_public_key) { 'openssh-public-key' }
    let(:test_authorized_keys) { File.join(Dir.mktmpdir, 'test_authorized_keys') }

    it 'should load settings' do
      expect(registry).to receive(:get_openssh_key).and_return(nil)
      expect(registry).to receive(:get_settings).and_return(settings)

      expect(subject.load_settings).to eql(settings)
    end

    it 'should setup openssh public key' do
      expect(registry).to receive(:get_openssh_key).and_return(openssh_public_key)
      expect(registry).to receive(:get_settings).and_return(nil)

      allow(subject).to receive(:authorized_keys).and_return(test_authorized_keys)
      expect(FileUtils).to receive(:mkdir_p).with(File.dirname(test_authorized_keys))
      expect(FileUtils).to receive(:chmod).with(0700, File.dirname(test_authorized_keys))
      expect(FileUtils).to receive(:chown).with(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP,
                                            File.dirname(test_authorized_keys)).and_return(true)
      expect(FileUtils).to receive(:chmod).with(0644, test_authorized_keys)
      expect(FileUtils).to receive(:chown).with(Bosh::Agent::BOSH_APP_USER, Bosh::Agent::BOSH_APP_GROUP,
                                            test_authorized_keys).and_return(true)

      subject.load_settings
      expect(File.open(test_authorized_keys, 'r') { |f| f.read }).to eql(openssh_public_key)
    end
  end

  describe :get_network_settings do
    let(:network_info) do
      double('net_info', default_gateway_interface: 'eth0', default_gateway: '10.0.0.1',
                         primary_dns: '1.1.1.1', secondary_dns: '2.2.2.2')
    end

    it 'should get network settings for dhcp networks' do
      expect(Bosh::Agent::Util).to receive(:get_network_info).and_return(network_info)

      expect(subject.get_network_settings('default', { 'type' => 'dynamic' })).to eql(network_info)
    end

    it 'should return nil for manual networks' do
      expect(Bosh::Agent::Util).to_not receive(:get_network_info)

      expect(subject.get_network_settings('default', { 'type' => 'manual' })).to be_nil
    end

    it 'should return nil no for manual networks' do
      expect(Bosh::Agent::Util).to_not receive(:get_network_info)

      expect(subject.get_network_settings('default', { 'type' => 'vip' })).to be_nil
    end

    it 'should raise a StateError exception when network is not supported' do
      expect do
        subject.get_network_settings('default', { 'type' => 'unknown' })
      end.to raise_error(Bosh::Agent::StateError, /Unsupported network type 'unknown'/)
    end
  end
end
