require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class RestoreController < BaseController
      post '/', :consumes => :multipart do
        options = {}
        @restore_manager.create_restore(current_user, params[:nginx_upload_path], options)
        redirect "/info"
      end
    end
  end
end
