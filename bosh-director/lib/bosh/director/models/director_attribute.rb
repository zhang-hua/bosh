module Bosh::Director::Models
  class DirectorAttribute < Sequel::Model(Bosh::Director::Config.db)
    def validate
      validates_presence :name
    end

    def self.find_or_create_uuid
      uuid = first(name: 'uuid')
      return uuid.value if uuid

      begin
        create(name: 'uuid', value: SecureRandom.uuid).value
      rescue Sequel::DatabaseError
        # Database will throw an error in case of race condition
        # causing multiple uuid records being inserted
        first(name: 'uuid').value
      end
    end
  end
end
