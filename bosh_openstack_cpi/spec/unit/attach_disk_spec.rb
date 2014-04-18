require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:server) { double('server', :id => 'i-test', :name => 'i-test', :flavor =>  { 'id' => 'f-test'},
                        :config_drive => config_drive ) }
  let(:volume) { double('volume', :id => 'v-foobar') }
  let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 10, :swap => '') }
  let(:config_drive) { nil }
  let(:cloud)  {
    mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with('i-test').and_return(server)
      expect(openstack.volumes).to receive(:get).with('v-foobar').and_return(volume)
      expect(openstack.flavors).to receive(:find).and_return(flavor)
    end
  }

  before(:each) do
    @registry = mock_registry
  end

  it 'attaches an OpenStack volume to a server' do
    volume_attachments = []
    attachment = double('attachment', :device => '/dev/sdc')

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).to receive(:attach).with(server.id, '/dev/sdc').and_return(attachment)
    expect(cloud).to receive(:wait_resource).with(volume, :'in-use')

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sdc'
        }
      }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'picks available device name' do
    volume_attachments = [{'volumeId' => 'v-c', 'device' => '/dev/vdc'},
                          {'volumeId' => 'v-d', 'device' => '/dev/xvdd'}]
    attachment = double('attachment', :device => '/dev/sdd')

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).to receive(:attach).with(server.id, '/dev/sde').and_return(attachment)
    expect(cloud).to receive(:wait_resource).with(volume, :'in-use')

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sde'
        }
      }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'raises an error when sdc..sdz are all reserved' do
    volume_attachments = ('c'..'z').inject([]) do |array, char|
      array << {'volumeId' => "v-#{char}", 'device' => "/dev/sd#{char}"}
      array
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)

    expect {
      cloud.attach_disk('i-test', 'v-foobar')
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

  it 'bypasses the attaching process when volume is already attached to a server' do
    volume_attachments = [{'volumeId' => 'v-foobar', 'device' => '/dev/sdc'}]
    attachment = double('attachment', :device => '/dev/sdd')

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).with('i-test').and_return(server)
      expect(openstack.volumes).to receive(:get).with('v-foobar').and_return(volume)
    end

    expect(server).to receive(:volume_attachments).and_return(volume_attachments)
    expect(volume).to_not receive(:attach)

    old_settings = { 'foo' => 'bar'}
    new_settings = {
        'foo' => 'bar',
        'disks' => {
            'persistent' => {
                'v-foobar' => '/dev/sdc'
            }
        }
    }

    expect(@registry).to receive(:read_settings).with('i-test').and_return(old_settings)
    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  context 'first device name letter' do
    before do
      allow(server).to receive(:volume_attachments).and_return([])
      allow(cloud).to receive(:wait_resource)
      allow(cloud).to receive(:update_agent_settings)
    end

    context 'when there is no ephemeral and swap disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 0, :swap => '') }

      it 'return letter b' do
        expect(volume).to receive(:attach).with(server.id, '/dev/sdb')

        cloud.attach_disk('i-test', 'v-foobar')
      end

      context 'with config_drive' do
        let(:config_drive) { '1' }

        it 'return letter c' do
          expect(volume).to receive(:attach).with(server.id, '/dev/sdc')

          cloud.attach_disk('i-test', 'v-foobar')
        end
      end
    end

    context 'when there is ephemeral disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 1024, :swap => '') }

      it 'return letter c' do
        expect(volume).to receive(:attach).with(server.id, '/dev/sdc')

        cloud.attach_disk('i-test', 'v-foobar')
      end

      context 'with config_drive' do
        let(:config_drive) { '1' }

        it 'return letter d' do
          expect(volume).to receive(:attach).with(server.id, '/dev/sdd')

          cloud.attach_disk('i-test', 'v-foobar')
        end
      end
    end

    context 'when there is swap disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 0, :swap => 200) }

      it 'return letter c' do
        expect(volume).to receive(:attach).with(server.id, '/dev/sdc')

        cloud.attach_disk('i-test', 'v-foobar')
      end

      context 'with config_drive' do
        let(:config_drive) { '1' }

        it 'return letter d' do
          expect(volume).to receive(:attach).with(server.id, '/dev/sdd')

          cloud.attach_disk('i-test', 'v-foobar')
        end
      end
    end

    context 'when there is ephemeral and swap disk' do
      let(:flavor) { double('flavor', :id => 'f-test', :ephemeral => 1024, :swap => 200) }

      it 'returns letter d' do
        expect(volume).to receive(:attach).with(server.id, '/dev/sdd')

        cloud.attach_disk('i-test', 'v-foobar')
      end

      context 'with config_drive' do
        let(:config_drive) { '1' }

        it 'return letter e' do
          expect(volume).to receive(:attach).with(server.id, '/dev/sde')

          cloud.attach_disk('i-test', 'v-foobar')
        end
      end
    end

    context 'when server flavor is not found' do
      let(:flavor) { nil }

      it 'returns letter b' do
        expect(volume).to receive(:attach).with(server.id, '/dev/sdb')

        cloud.attach_disk('i-test', 'v-foobar')
      end

      context 'with config_drive' do
        let(:config_drive) { '1' }

        it 'return letter c' do
          expect(volume).to receive(:attach).with(server.id, '/dev/sdc')

          cloud.attach_disk('i-test', 'v-foobar')
        end
      end
    end
  end
 end
