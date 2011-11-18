module Cachy
  extend ActiveSupport::Concern

  def self.set_cache_config(cache_config)
    @cache_config = cache_config
  end

  def self.cache_config
    @cache_config ||= { :version => 1 }
  end

  def self.set_cache(cache)
    @cache = cache
  end

  def self.cache
    @cache ||= Rails.cache
  end

  def self.digest(key, options = {})
    key = key.map { |v| "#{v}" }.join(':') if key.is_a?(::Array)
    key = key.sort_by { |k, v| "#{k}" }.join(':') if key.is_a?(::Hash)
    key = "#{key}" unless key.is_a?(::String)

    key = "version:#{cache_config[:version]}:#{key}" unless options[:no_version]
    key = "locale:#{I18n.locale}:#{key}" unless options[:no_locale]
    key = Digest::SHA1.hexdigest(key) unless options[:no_sha]

    key
  end

  def self.autoload(object)
    # In console, somehow we have missing constants error.
    # It doesn't happen in production though.
    if object.frozen? && object.is_a?(::String) && object =~ /ActiveSupport::Cache::Entry/
      obj = Marshal.load(object)
      return obj.value
    else
      object
    end
  rescue ArgumentError => error
    lazy_load ||= Hash.new { |hash, hash_key| hash[hash_key] = true; false }

    if error.to_s[/undefined class|referred/] && !lazy_load[error.to_s.split.last.constantize]
      retry
    else
      raise error
    end
  end

  def self.cache_option_keys
    @cache_option_keys ||= [:expires_in]
  end

  def self.digest_option_keys
    @digest_option_keys ||= [:no_version, :no_locale, :no_sha]
  end

  module ClassMethods
    def set_cachy_options(options)
      @cachy_options = cachy_options.merge(options)
    end

    def cachy_options
      @cachy_options ||= { :expires_in => 1.day, :no_locale => true }
    end

    def caches_method(name, options = {})
      class_key = "#{self.name}:#{name}"

      options.reverse_merge!(cachy_options)

      block_if = options[:if]
      block_with_key = options[:with_key]
      block_with_key ||= :id # id of the object is the default key.
      block_after_load = options[:after_load]

      class_eval do
        define_method "#{name}_via_cache" do |*args|
          cache_key = block_with_key.is_a?(Proc) ? block_with_key.call(self, *args) : self.send(block_with_key)
          cache_key = ::Cachy.digest(cache_key, options.slice(*::Cachy.digest_option_keys))

          variable = "@cachy_#{name}_#{cache_key}"
          unless instance_variable_defined?(variable)
            object = if block_if && block_if.call(self, *args) == false
              send(name, *args)
            else
              if defined?(Rails) && !Rails.env.production?
                Rails.logger.info "#{class_key}:#{cache_key}"
                Rails.logger.info options.slice(*::Cachy.cache_option_keys).inspect
              end

              obj = ::Cachy.cache.fetch("#{class_key}:#{cache_key}", options.slice(*::Cachy.cache_option_keys)) do
                send(name, *args)
              end
              ::Cachy.autoload(obj)
            end

            block_after_load.call(object) if block_after_load

            instance_variable_set(variable, object)
          end

          instance_variable_get(variable)
        end

        define_method "clear_cache_#{name}" do |*args|
          cache_key = block_with_key.is_a?(Proc) ? block_with_key.call(self, *args) : self.send(block_with_key)
          cache_key = ::Cachy.digest(cache_key, options.slice(*::Cachy.digest_option_keys))

          variable = "@cachy_#{name}_#{cache_key}"
          remove_instance_variable(variable) if instance_variable_defined?(variable)

          ::Cachy.cache.delete("#{class_key}:#{cache_key}")
        end
      end

    end

    def caches_methods(*names, &block)
      options = names.extract_options!
      names.each do |name|
        caches_method(name, options, &block)
      end
    end

    def caches_class_method(name, options = {})
      options.reverse_merge!(cachy_options)
      block_if = options[:if]
      block_with_key = options[:key]
      block_after_load = options[:after_load]

      class_key = "#{self.name}:class:#{name}"
      (class << self; self; end).instance_eval do
        define_method "#{name}_via_cache" do |*args|
          cache_key = if block_cache_key
            block_cache_key.call(*args)
          else
            *args
          end
          cache_key = ::Cachy.digest(cache_key, options.slice(*::Cachy.digest_option_keys))

          object = if block_if && block_if.call(*args) == false
            send(name, *args)
          else
            if defined?(Rails) && !Rails.env.production?
              Rails.logger.info "#{class_key}:#{cache_key}"
              Rails.logger.info options.slice(*::Cachy.cache_option_keys).inspect
            end

            obj = ::Cachy.cache.fetch("#{class_key}:#{cache_key}", options.slice(*::Cachy.cache_option_keys)) do
              send(name, *args)
            end

            ::Cachy.autoload(obj)
          end

          block_after_load.call(object) if block_after_load

          object
        end

        define_method "clear_cache_#{name}" do |*args|
          cache_key = block_cache_key ? block_cache_key.call(*args) : *args
          cache_key = ::Cachy.digest(cache_key, options.slice(*::Cachy.digest_option_keys))

          ::Cachy.cache.delete("#{class_key}:#{cache_key}")
        end
      end

    end

    def caches_class_methods(*names)
      options = names.extract_options!
      names.each do |name|
        caches_class_method(name, options, &block)
      end
    end
  end

end