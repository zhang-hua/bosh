module Bosh::Director
  class Data
    def initialize(args)
      raise StandardError unless args.is_a? Hash
      args.each {|k,v|
        instance_variable_set "@#{k}", v if self.class.props.member?(k)
      }
    end
  end
end
