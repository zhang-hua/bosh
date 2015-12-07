module Bosh::Cli::Command
class Restore < Base

    usage 'restore-director'
    desc 'Restore BOSH director database'
    def restore(path, options={})
      auth_required
      show_current_state

      unless File.exists?(path)
        err("The file at `#{path}' does not exist.")
      end

      unless File.readable?(path)
        err("The file at `#{path}' is not readable.")
      end

      status, task_id = director.create_restore(path, options)

      if status == :done
        say("Starting restore of BOSH director.")
      else
        [status, task_id]
      end

      say("Restore done!")

    end

    private

  end
end
