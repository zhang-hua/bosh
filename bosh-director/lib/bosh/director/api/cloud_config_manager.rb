module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(iaas_config_yaml)
          iaas_config = Bosh::Director::Models::IaasConfig.new(
            properties: iaas_config_yaml
          )
          iaas_config.save
        end

        def list(limit)
          Bosh::Director::Models::IaasConfig.list(limit)
        end

        def latest
          Bosh::Director::Models::IaasConfig.latest
        end
      end
    end
  end
end
