require 'spec_helper'
require 'bosh/director/dns_helper'

module Bosh::Director
  module DeploymentPlan
    describe Plan do
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      describe '#from_manifest' do
        let(:deployment_manifest) { ManifestHelper.default_deployment_manifest }
        let(:iaas_manifest) {ManifestHelper.default_iaas_manifest}

        #TODO: iaas_manifests are defined in nested let blocks, and always
        #      saved off in this top level block. Fix this to be more local.
        before do
          iaas_config = Bosh::Director::Models::IaasConfig.new
          iaas_config.manifest = iaas_manifest
          iaas_config.save
        end

        it 'returns a Plan' do
          expect(Plan.from_manifest(deployment_manifest)).to be_a(Plan)
        end

        describe 'the returned Plan' do
          it 'includes the specified name' do
            plan = Plan.from_manifest(ManifestHelper.default_deployment_manifest('foo'))
            expect(plan.name).to eq('foo')
          end

          context 'when properties are provided' do
            let(:properties_settings) { { 'foo' => 'bar' } }
            before {  deployment_manifest.merge!('properties' => properties_settings) }

            it 'includes the specified properties' do
              plan = Plan.from_manifest(deployment_manifest)
              expect(plan.properties).to eq(properties_settings)
            end
          end

          context 'when properties are not provided' do
            before {  deployment_manifest.delete('properties') }

            it 'defaults properties to an empty hash' do
              plan = Plan.from_manifest(deployment_manifest)
              expect(plan.properties).to eq({})
            end
          end

          context 'when a "release" section is specified' do
            before { deployment_manifest['release'] = ManifestHelper.release }
            before { deployment_manifest.delete('releases') }

            it 'includes the specified release' do
              plan = Plan.from_manifest(deployment_manifest)
              expect(plan.releases.length).to eq(1)
              release = ManifestHelper.release
              expect(plan.releases[0].name).to eq(release['name'])
              expect(plan.releases[0].version).to eq(release['version'])
            end
          end

          context 'when a "releases" section is specified' do
            before { deployment_manifest['releases'] = [ManifestHelper.release] }
            before { deployment_manifest.delete('release') }

            it 'includes the specified release' do
              plan = Plan.from_manifest(deployment_manifest)
              expect(plan.releases.length).to eq(1)
              release = ManifestHelper.release
              expect(plan.releases[0].name).to eq(release['name'])
              expect(plan.releases[0].version).to eq(release['version'])
            end
          end

          context 'when "releases" and "release" sections are both specified' do
            before { deployment_manifest['release'] = ManifestHelper.release }
            before { deployment_manifest['releases'] = [ManifestHelper.release] }

            it 'raises an exception' do
              expect {
                Plan.from_manifest(deployment_manifest)
              }.to raise_error(DeploymentAmbiguousReleaseSpec)
            end
          end

          context 'when neither "releases" nor "release" sections are specified' do
            before { deployment_manifest.delete('release') }
            before { deployment_manifest.delete('releases') }

            it 'raises an exception' do
              expect {
                Plan.from_manifest(deployment_manifest)
              }.to raise_error(ValidationMissingField)
            end
          end

          context 'when a compilation section is specified' do
            let(:cloud_properties) { { 'foo' => 'bar' } }
            let(:iaas_manifest) do
              c = ManifestHelper.default_iaas_manifest
              c['compilation']['cloud_properties'] = cloud_properties
              c
            end

            it 'includes the specified compilation settings' do
              plan = Plan.from_manifest(deployment_manifest)

              compilation = plan.compilation
              expect(compilation).to be_a(CompilationConfig)
              expect(compilation.cloud_properties).to eq(cloud_properties)
            end
          end


          context 'when an update section is specified' do
            it 'includes the specified updates' do
              plan = Plan.from_manifest(deployment_manifest)

              update = plan.update
              expect(update).to be_a(UpdateConfig)
              expect(update.canaries).to eq(2)
            end
          end

          context 'when an update section is not specified' do
            before { deployment_manifest.delete('update') }

            it 'raises an exception' do
              expect {
                Plan.from_manifest(deployment_manifest)
              }.to raise_error(ValidationMissingField)
            end
          end

          it 'allows network look up by name' do
            plan = Plan.from_manifest(deployment_manifest)
            expect(plan.network('network-name').name).to eq('network-name')
          end

          context 'when there is no cloud manifest' do
            before do
              Bosh::Director::Models::IaasConfig.latest.destroy
            end

            context 'and the deployment manifest can resolve all IaaS dependencies' do
              let(:deployment_manifest) { ManifestHelper.default_legacy_manifest }

              it 'uses the networks from the deployment manifest' do
                plan = Plan.from_manifest(deployment_manifest)
                expect(plan.network('network-name').name).to eq('network-name')
              end
            end
          end

          describe 'resource pools' do
            context 'when each has a unique name' do
              let(:iaas_manifest) do
                iaas_manifest = ManifestHelper.default_iaas_manifest
                iaas_manifest['resource_pools'] = [
                  ManifestHelper.resource_pool('rp1-name'),
                  ManifestHelper.resource_pool('rp2-name'),
                ]
                iaas_manifest
              end

              it 'includes the specified resource pools' do
                plan = Plan.from_manifest(deployment_manifest)

                resource_pools = plan.resource_pools
                expect(resource_pools.length).to eq(2)
                expect(resource_pools[0]).to be_a(ResourcePool)
                expect(resource_pools[0].name).to eq('rp1-name')
                expect(resource_pools[1].name).to eq('rp2-name')
              end

              it 'allows look up by name' do
                plan = Plan.from_manifest(deployment_manifest)
                expect(plan.resource_pool('rp1-name').name).to eq('rp1-name')
                expect(plan.resource_pool('rp2-name').name).to eq('rp2-name')
              end
            end

            context 'when there is no cloud manifest' do
              before do
                Bosh::Director::Models::IaasConfig.latest.destroy
              end

              context 'and the deployment manifest can resolve all IaaS dependencies' do
                let(:deployment_manifest) { ManifestHelper.default_legacy_manifest }

                it 'uses the resource pools from the deployment manifest' do
                  plan = Plan.from_manifest(deployment_manifest)
                  expect(plan.resource_pool('rp-name').name).to eq('rp-name')
                end
              end
            end
          end

          describe 'disk pools' do
            context 'when each has a unique name' do
              let(:iaas_manifest) do
                iaas_manifest = ManifestHelper.default_iaas_manifest
                iaas_manifest['disk_pools'] = [
                  ManifestHelper.disk_pool('dp1-name'),
                  ManifestHelper.disk_pool('dp2-name'),
                ]
                iaas_manifest
              end

              it 'includes the specified resource pools' do
                plan = Plan.from_manifest(deployment_manifest)

                disk_pools = plan.disk_pools
                expect(disk_pools.length).to eq(2)
                expect(disk_pools[0]).to be_a(DiskPool)
                expect(disk_pools[0].name).to eq('dp1-name')
                expect(disk_pools[1].name).to eq('dp2-name')
              end

              it 'allows look up by name' do
                plan = Plan.from_manifest(deployment_manifest)
                expect(plan.disk_pool('dp1-name').name).to eq('dp1-name')
                expect(plan.disk_pool('dp2-name').name).to eq('dp2-name')
              end
            end

            context 'when there is no cloud manifest' do
              before do
                Bosh::Director::Models::IaasConfig.latest.destroy
              end

              context 'and the deployment manifest can resolve all IaaS dependencies' do
                let(:deployment_manifest) do
                  deployment_manifest = ManifestHelper.default_legacy_manifest
                  deployment_manifest['disk_pools'] = [ ManifestHelper.disk_pool ]
                  deployment_manifest
                end

                it 'uses the networks from the deployment manifest' do
                  plan = Plan.from_manifest(deployment_manifest)
                  expect(plan.disk_pools.map(&:name)).to eq(['dp-name'])
                end
              end
            end
          end

          describe 'jobs' do
            context 'when each has a unique name' do
              before {
                deployment_manifest['jobs'] = [
                  ManifestHelper.job('job1-name'),
                  ManifestHelper.job('job2-name'),
                ]
              }

              it 'includes the specified resource pools' do
                plan = Plan.from_manifest(deployment_manifest)

                jobs = plan.jobs
                expect(jobs.length).to eq(2)
                expect(jobs[0]).to be_a(Job)
                expect(jobs[0].name).to eq('job1-name')
                expect(jobs[1].name).to eq('job2-name')
              end

              it 'allows look up by name' do
                plan = Plan.from_manifest(deployment_manifest)
                expect(plan.job('job1-name').name).to eq('job1-name')
                expect(plan.job('job2-name').name).to eq('job2-name')
              end
            end

            context 'when jobs have duplicate canonical names' do
              before {
                deployment_manifest['jobs'] = [
                  ManifestHelper.job('job-name'),
                  ManifestHelper.job('JOB-NAME'),
                ]
              }

              it 'raises an exception' do
                expect {
                  Plan.from_manifest(deployment_manifest)
                }.to raise_error(DeploymentCanonicalJobNameTaken)
              end
            end

            context 'when templates are not defined' do
              before {
                job1 = ManifestHelper.job
                job1.delete('templates')
                deployment_manifest['jobs'] = [job1]
              }

              it 'raises an exception' do
                expect {
                  Plan.from_manifest(deployment_manifest)
                }.to raise_error(ValidationMissingField)
              end
            end

            context 'when no matching release is specified' do
              before {
                deployment_manifest['releases'] = []
                deployment_manifest['jobs'] = [ManifestHelper.job]
              }

              it 'raises an exception' do
                expect {
                  Plan.from_manifest(deployment_manifest)
                }.to raise_error(JobMissingRelease)
              end
            end

            context 'when trying to rename a job that is still in-use' do
              before {
                deployment_manifest['jobs'] = [ManifestHelper.job]
              }

              it 'raises an exception' do
                options = {
                  'job_rename' => {
                    'old_name' => ManifestHelper.job['name'],
                    'new_name' => 'renamed-job',
                  }
                }
                expect {
                  Plan.from_manifest(deployment_manifest, options)
                }.to raise_error(DeploymentRenamedJobNameStillUsed)
              end
            end
          end
        end
      end
    end
  end
end
