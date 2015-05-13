require 'spec_helper'

describe 'multiple deployments', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['networks'].first['subnets'].first['static'] = %w(192.168.1.10)
    cloud_config_hash['resource_pools'].first.delete('size')
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  it 'assigns available dynamic ips in the same network' do
    first_manifest_hash = Bosh::Spec::Deployments.simple_manifest
    first_manifest_hash['name'] = 'first'
    first_manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: first_manifest_hash)
    vms = bosh_runner.run('vms --details')
    puts vms
    expect(vms).to include('192.168.1.2')

    second_manifest_hash = Bosh::Spec::Deployments.simple_manifest
    second_manifest_hash['name'] = 'second'
    second_manifest_hash['jobs'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: second_manifest_hash)
    vms = bosh_runner.run('vms --details')
    puts vms
    expect(vms).to include('192.168.1.2') # first
    expect(vms).to include('192.168.1.3') # second
  end

  it 'fails to assign the same static ip between deployments' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['networks'].first['static_ips'] = '192.168.1.10'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    vm = director.vms.first
    expect(vm.get_state['networks']['a']['ip']).to eq('192.168.1.10')

    second_manifest_hash = Bosh::Spec::Deployments.simple_manifest
    second_manifest_hash['name'] = 'second'
    second_manifest_hash['jobs'].first['instances'] = 1
    second_manifest_hash['jobs'].first['networks'].first['static_ips'] = '192.168.1.10'
    _, exit_code = deploy_simple_manifest(manifest_hash: second_manifest_hash, return_exit_code: true)
    puts bosh_runner.print_task_debug_logs(5, {})
    expect(exit_code).to eq(1)
  end
end
