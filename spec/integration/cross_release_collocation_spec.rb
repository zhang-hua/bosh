require 'spec_helper'

describe 'collocating templates from 2 releases' do
  include IntegrationExampleGroup

  let(:extras) do
    {
      'name' => 'simple',
      'releases' => [
        {
          'name' => 'dummy',
          'version' => 'latest',
        },
        {
          'name' => 'dummy2',
          'version' => 'latest',
        },
      ],

      'networks' => [
        {
          'name' => 'a',
          'subnets' => [
            {
              'range' => '192.168.1.0/24',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => ['192.168.1.10'],
              'reserved' => [],
              'cloud_properties' => {},
            }
          ]
        }
      ],

      'resource_pools' => [
        {
          'name' => 'a',
          'size' => 3,
          'cloud_properties' => {},
          'network' => 'a',
          'stemcell' => {
            'name' => 'ubuntu-stemcell',
            'version' => '1'
          }
        }
      ],
    }
  end

  context 'when the template packages do not collide' do
    let(:jobs) do
      [
        {
          'name' => 'foobar',
          'templates' => [
            {
              'name' => 'dummy_with_package',
              'release' => 'dummy',
            },
            {
              'name' => 'dummy',
              'release' => 'dummy2',
            },
          ],

          'resource_pool' => 'a',
          'instances' => 1,
          'networks' => [{'name' => 'a'}]
        }
      ]
    end

    it 'successfully deploys' do
      base_manifest = make_collocated_manifest
      manifest_hash = base_manifest.merge(extras).merge('jobs' => jobs)

      upload_stemcell_and_releases

      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")

      output = run_bosh("deploy")
      expect($?).to be_success
      p output
    end
  end

  context 'when 2 templates depend on packages with the same name' do
    let(:jobs) {
      [
        {
          'name' => 'foobar',
          'templates' => [
            {
              'name' => 'dummy_with_package',
              'release' => 'dummy',
            },
            {
              'name' => 'template2',
              'release' => 'dummy2',
            },
          ],

          'resource_pool' => 'a',
          'instances' => 1,
          'networks' => [{'name' => 'a'}]
        }
      ]
    }

    it 'refuses to deploy' do
      base_manifest = make_collocated_manifest
      manifest_hash = base_manifest.merge(extras).merge('jobs' => jobs)

      upload_stemcell_and_releases

      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")

      output = run_bosh("deploy", failure_expected: true)
      expect($?).not_to be_success
      expect(output).to match(/Cannot tell which release to use for job `foobar'. Please reference an existing release./)
    end
  end

  def make_collocated_manifest
    minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
    minimal_manifest.delete('release')
    minimal_manifest
  end

  def upload_stemcell_and_releases
    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    run_bosh("upload release #{spec_asset('dummy-release.tgz')}")
    run_bosh("upload release #{spec_asset('dummy2-release.tgz')}")
    run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
  end
end
