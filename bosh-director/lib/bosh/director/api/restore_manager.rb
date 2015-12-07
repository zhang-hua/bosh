module Bosh::Director
  module Api
    class RestoreManager
      def initialize
      end

      def create_restore(username, path, options={})
        result = Bosh::Exec.sh("monit restart director", :on_error => :return)
        if result.failed?
          logger.error("Failed to restart director, returned #{result.exit_status}, output: #{result.output})")
          raise SystemError, "Restore director failed. Check debug log for details."
        end
      end
    end
  end
end
