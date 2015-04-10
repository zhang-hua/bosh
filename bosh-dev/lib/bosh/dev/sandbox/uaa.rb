require 'bosh/dev'
require 'bosh/core/shell'

module Bosh::Dev::Sandbox
  class Uaa
    REPO_ROOT = File.expand_path('../../../../../', File.dirname(__FILE__))
    RELEASE_ROOT = File.join(REPO_ROOT, 'release')
    UAA_CONFIG_DIR = File.expand_path('bosh-dev/assets/sandbox', REPO_ROOT)

    def initialize(port, log_base, logger, runner = Bosh::Core::Shell.new)
      @port = port
      @log_base = log_base
      @logger = logger
      @runner = runner
      @install_dir = File.join(REPO_ROOT, 'tmp', 'integration-uaa')
    end

    attr_reader :service

    def install
      FileUtils.rm_rf(@install_dir)
      FileUtils.mkdir_p(@install_dir)

      tomcat_url = 'https://s3.amazonaws.com/bosh-dependencies/apache-tomcat-8.0.21.tar.gz'
      out = `curl -L #{tomcat_url} | (cd #{@install_dir} && tar xfz -)`
      raise out unless $? == 0

      uaa_url = 'https://s3.amazonaws.com/bosh-dependencies/cloudfoundry-identity-uaa-2.0.3.war'
      webapp_path = File.join(tomcat_dir, 'webapps', 'uaa.war')
      out = `curl --output #{webapp_path} -L #{uaa_url}`
      raise out unless $? == 0
    end

    def start
      server_xml = File.join(UAA_CONFIG_DIR, 'tomcat-server.xml')
      log_path = "#{@log_base}.uaa.out"
      opts = {
        "uaa.http_port" => @port,
        "uaa.access_log_dir" => File.dirname(log_path),
      }
      @service = Service.new([executable_path, 'run', '-config', server_xml],
        {
          output: log_path,
          env: {
            'CATALINA_OPTS' => opts.map {|k,v| "-D#{k}=#{v}"}.join(" "),
            'UAA_CONFIG_PATH' => UAA_CONFIG_DIR
          }
        },
        @logger,
      )

      @uaa_socket_connector = SocketConnector.new('uaa', 'localhost', @port, @logger)

      @service.start
    end

    def await
      @uaa_socket_connector.try_to_connect(1000)
    end

    def stop
      @service.stop
    end

    private

    def tomcat_dir
      File.join(@install_dir, 'apache-tomcat-8.0.21')
    end

    def executable_path
      File.join(tomcat_dir, 'bin', 'catalina.sh')
    end
  end
end
