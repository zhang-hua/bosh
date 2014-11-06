require 'bosh/dev/stemcell_artifacts'
require 'bosh/dev/stemcell_artifact'
require 'bosh/dev/release_artifact'
require 'bosh/dev/gem_components'
require 'bosh/dev/gem_artifact'

module Bosh::Dev
  class PromotableArtifacts
    def initialize(build_number, logger)
      @build_number = build_number
      @logger = logger
      @release = ReleaseArtifact.new(build_number, @logger)
    end

    def all
      gem_artifacts + release_artifacts + stemcell_artifacts
    end

    def release_file
      @release.name
    end

    private

    def gem_artifacts
      gem_components = GemComponents.new(@build_number)
      source = Bosh::Dev::UriProvider.pipeline_s3_path("#{@build_number}", '')
      gem_components.components.map { |component| GemArtifact.new(component, source, @build_number, @logger) }
    end

    def release_artifacts
      [ @release ]
    end

    def stemcell_artifacts
      StemcellArtifacts.all(@build_number, @logger).list
    end
  end
end
