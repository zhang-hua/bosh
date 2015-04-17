require 'spec_helper'
require 'bosh/director/dns_helper'

module Bosh::Director
  module Manifests
    describe IaasManifest do
      let(:iaas_manifest) { ManifestHelper.default_iaas_manifest }

      describe '#pluck_from_deployment_manifest!' do
        it 'splits the deployment manifest into IaaS specific and non IaaS specific manifests' do
          legacy_manifest = ManifestHelper.default_legacy_manifest
          iaas_manifest = IaasManifest.pluck_from_deployment_manifest!(legacy_manifest)
          expect(iaas_manifest).to eq(ManifestHelper.default_iaas_manifest)
          expect(legacy_manifest).to eq(ManifestHelper.default_deployment_manifest)
        end
      end

      describe '#clean' do
        context 'when no compilation section is specified' do
          before { iaas_manifest.delete('compilation') }

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(ValidationMissingField)
          end
        end

        context 'when network type is not specified' do
          before { iaas_manifest['networks'] = [ManifestHelper::network] }

          it 'creates a manual network by default' do
            clean_manifest = IaasManifest.new(iaas_manifest).clean

            networks = clean_manifest['networks']
            expect(networks.length).to eq(1)
            expect(networks[0]['type']).to eq('manual')
            expect(networks[0]['name']).to eq('network-name')
          end
        end

        context 'when networks have duplicate canonical names' do
          before do
            iaas_manifest['networks'] = [
              ManifestHelper::network('network-name'),
              ManifestHelper::network('NETWORK-NAME'),
            ]
          end

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(DeploymentCanonicalNetworkNameTaken)
          end
        end

        context 'when an empty networks section is specified' do
          before { iaas_manifest['networks'] = [] }

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(DeploymentNoNetworks)
          end
        end

        context 'when the networks section is missing' do
          before { iaas_manifest.delete('networks') }

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(ValidationMissingField)
          end
        end

        context 'when resource pools have duplicate names' do
          before do
            iaas_manifest['resource_pools'] = [
              ManifestHelper::resource_pool('rp-name'),
              ManifestHelper::resource_pool('rp-name'),
            ]
          end

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(DeploymentDuplicateResourcePoolName)
          end
        end

        context 'when disk pools have duplicate canonical names' do
          before do
            iaas_manifest['disk_pools'] = [
              ManifestHelper::disk_pool('dp-name'),
              ManifestHelper::disk_pool('dp-name'),
            ]
          end

          it 'raises an exception' do
            expect {
              IaasManifest.new(iaas_manifest).clean
            }.to raise_error(DeploymentDuplicateDiskPoolName)
          end
        end
      end
    end
  end
end
