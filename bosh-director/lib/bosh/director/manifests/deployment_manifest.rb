module Bosh
  module Director
    module Manifests
      class DeploymentManifest
        include Bosh::Director::ValidationHelper

        def initialize(deployment_manifest)
          @deployment_manifest = deployment_manifest
        end

        def clean
          safe_property(@deployment_manifest, 'name', :class => String)
          safe_property(@deployment_manifest, 'update', :class => Hash)

          @deployment_manifest['jobs'] = safe_property(@deployment_manifest, 'jobs', :class => Array, :default => [])
          @deployment_manifest['properties'] = safe_property(@deployment_manifest, 'properties', :class => Hash, :default => {})

          clean_releases

          @deployment_manifest
        end

        private

        def clean_releases
          if @deployment_manifest.has_key?('release')
            if @deployment_manifest.has_key?('releases')
              raise Bosh::Director::DeploymentAmbiguousReleaseSpec,
                "Deployment manifest contains both 'release' and 'releases' " +
                  'sections, please use one of the two.'
            end
            @deployment_manifest['releases'] = [@deployment_manifest['release']]
            @deployment_manifest.delete('release')
          else
            safe_property(@deployment_manifest, 'releases', :class => Array)
          end
        end
      end
    end
  end
end
