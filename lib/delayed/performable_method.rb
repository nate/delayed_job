require 'active_support/core_ext/module/delegation'

module Delayed
  class PerformableMethod < Struct.new(:object, :method_name, :args)

    class ActiveRecordSerializer < Struct.new(:klass, :primary_key)
      def self.serialize(object)
        new(object.class, object.send(object.class.primary_key))
      end

      def load
        ActiveRecord::Base.yaml_new(klass, nil, {'attributes' => {klass.primary_key => primary_key}})
      end
    end

    delegate :method, :to => :object

    attr_writer :to_yaml_properties

    def initialize(object, method_name, args)
      raise NoMethodError, "undefined method `#{method_name}' for #{object.inspect}" unless object.respond_to?(method_name, true)

      if object.is_a?(ActiveRecordSerializer)
        self.object     = object.load
      else
        self.object     = object
      end

      self.args         = args
      self.method_name  = method_name.to_sym
    end

    def display_name
      "#{object.class}##{method_name}"
    end

    def perform
      object.send(method_name, *args) if object
    end

    def method_missing(symbol, *args)
      object.send(symbol, *args)
    end

    def respond_to?(symbol, include_private=false)
      super || object.respond_to?(symbol, include_private)
    end

    def object
      o = super

      if o.is_a?(ActiveRecordSerializer) && !Thread.current[:skip_object_deserialization]
        o.load
      else
        o
      end
    end

    def to_yaml(options={})
      if object.is_a?(ActiveRecord::Base)
        to_active_record_yaml(options)
      else
        super
      end
    end


  protected

    def to_active_record_yaml(options={})
      active_record_serialize_and_restore_object do
        skip_object_desirialization do
          to_yaml(options)
        end
      end
    end

    def skip_object_desirialization(&block)
      Thread.current[:skip_object_deserialization] = true
      block.call
    ensure
      Thread.current[:skip_object_deserialization] = false
    end

    def active_record_serialize_and_restore_object(&block)
      active_record_object = object
      self.object = ActiveRecordSerializer.serialize(object)
      block.call
    ensure
      self.object = active_record_object if active_record_object
    end

  end
end
