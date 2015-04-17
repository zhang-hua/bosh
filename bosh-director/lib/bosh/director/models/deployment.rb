module Bosh::Director::Models
  class Deployment < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :stemcells
    many_to_many :releases
    many_to_many :release_versions
    one_to_many  :job_instances, :class => "Bosh::Director::Models::Instance"
    one_to_many  :vms
    one_to_many  :properties, :class => "Bosh::Director::Models::DeploymentProperty"
    one_to_many  :problems, :class => "Bosh::Director::Models::DeploymentProblem"
    many_to_one   :iaas_config

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end

    Deployment < DeploymentModel, IaasModel

    def self.find_or_initialize_by_manifest(deployment_manifest, iaas_manifest)
      name = deployment_manifest['name']

      deployment_model = Deployment.find({:name => name })
      if deployment_model.nil?
        deployment_model = new_with_name(name)
      end

      deployment_model.deployment_manifest = deployment_manifest
      deployment_model.iaas_manifest = iaas_manifest
      deployment_model
    end

    def canonical_name
      DnsHelper.canonical(name)
    end

    def iaas_manifest
      @iaas_manifest ||= Psych.load(iaas_manifest_text)
    end

    def iaas_manifest= (iaas_manifest)
      iaas_manifest = Bosh::Director::Manifests::IaasManifest.new(iaas_manifest).clean
      self[:iaas_manifest_text] = Psych.dump(iaas_manifest)
      @iaas_manifest = iaas_manifest
    end

    def iaas_manifest_text= (text)
      @iaas_manifest = nil
      self[:iaas_manifest_text] = text
    end

    def manifest= (text)
      @deployment_manifest = nil
      self[:manifest] = text
    end

    def deployment_manifest
      @deployment_manifest ||= Psych.load(manifest)
    end

    def deployment_manifest= (deployment_manifest)
      deployment_manifest = Bosh::Director::Manifests::DeploymentManifest.new(deployment_manifest).clean
      self[:manifest] = Psych.dump(deployment_manifest) # manifest is a magical sequel model field
      @deployment_manifest = deployment_manifest
    end

    private

    def self.new_with_name(name)
      canonical_name = DnsHelper.canonical(name)

      #TODO: Canonical uniqueness should be enforced in the DB.
      Deployment.each do |other|
        if other.canonical_name == canonical_name
          raise DeploymentCanonicalNameTaken,
            "Invalid deployment name `#{@name}', " +
              'canonical name already taken'
        end
      end

      Deployment.new({:name => name})
    end

    class DnsHelper
      include  Bosh::Director::DnsHelper

      def self.canonical(name)
        DnsHelper.new.canonical(name)
      end
    end
  end

  Deployment.plugin :association_dependencies
  Deployment.add_association_dependencies :stemcells => :nullify, :problems => :destroy
end
