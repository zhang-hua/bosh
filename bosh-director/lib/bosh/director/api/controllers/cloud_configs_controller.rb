require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class CloudConfigsController < BaseController
      post '/', :consumes => :yaml do
        properties = request.body.string
        Bosh::Director::Api::CloudConfigManager.new.update(properties)

        status(201)
      end

      get '/' do
        if params['limit'].nil? || params['limit'].empty?
          status(400)
          body("limit is required")
          return
        end

        begin
          limit = Integer(params['limit'])
        rescue ArgumentError
          status(400)
          body("limit is invalid: '#{params['limit']}' is not an integer")
          return
        end

        iaas_configs = Bosh::Director::Api::CloudConfigManager.new.list(limit)
        json_encode(
          iaas_configs.map do |iaas_config|
            {
              "properties" => iaas_config.properties,
              "created_at" => iaas_config.created_at,
            }
        end
        )
      end
    end
  end
end
