module Bosh
  module Director
    module Models
      class IaasConfig < Sequel::Model(Bosh::Director::Config.db)
        def self.list(limit)
          order(Sequel.desc(:id)).limit(limit).to_a
        end

        def self.latest
          list(1).first
        end

        # def validate
        #   clean_manifest
        # rescue => e
        #   errors.add(:properties, e.message)
        # end

        def before_create
          self.created_at ||= Time.now
        end

        def clean_manifest
          @clean_manifest ||= begin
            unclean_manifest = Psych.load(properties)
            Bosh::Director::Manifests::IaasManifest.new(unclean_manifest).clean
          end unless properties.nil?
        end

        # def manifest= (manifest_hash)
        #   self.properties = Psych.dump(manifest_hash)
        # end

        def properties= (manifest_text)
          @manifest = nil
          self[:properties] = manifest_text
        end
      end
    end
  end
end
