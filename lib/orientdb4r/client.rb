module Orientdb4r

  class Client
    include Utils

    ###
    # Constructor.
    def initialize
      @connected = false
    end

    ###
    # Connects client to the server.
    def connect options
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Disconnects client from the server.
    def disconnect
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Gets flag whenever the client is connected or not.
    def connected?
      @connected
    end

    ###
    # Creates a new database.
    # You can provide an additional authentication to the server with 'database.create' resource
    # or the current one will be used.
    def create_database(options)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Gets informations about requested class.
    def get_class(name)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Executes a query against the database.
    def query(sql)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Executes a command against the database.
    def command(sql, options={})
      raise NotImplementedError, 'this should be overridden by concrete client'
    end

    ###
    # Creates a new class in the schema.
    def create_class(name, options={})
      raise ArgumentError, "class name is blank" if blank?(name)
      opt_pattern = { :extends => :optional , :cluster => :optional, :force => false }
      verify_options(options, opt_pattern)

      sql = "CREATE CLASS #{name}"
      sql << " EXTENDS #{options[:extends]}" if options.include? :extends
      sql << " CLUSTER #{options[:cluster]}" if options.include? :cluster

      drop_class name if options[:force]

      command sql, :http_code_500 => 'failed to create class (exists already, bad supperclass?)'

      if block_given?
        proxy = Orientdb4r::Utils::Proxy.new(self, name)
        def proxy.property(property, type, options={})
          self.target.send :create_property, self.context, property, type, options
        end
        yield proxy
      end
    end

    ###
    # Removes a class from the schema.
    def drop_class(name, options={})
      raise ArgumentError, "class name is blank" if blank?(name)

      # in :mode=>:strict verify if the class is no a super class
      opt_pattern = { :mode => :nil }
      verify_options(options, opt_pattern)
      unless :strict == options[:mode]
        response = @resource["connect/#{@database}"].get
        connect_info = process_response(response, :mode => :strict)
        children = connect_info['classes'].select { |i| i['superClass'] == name }
        unless children.empty?
          raise OrientdbError, "class is super-class, cannot be deleted, name=#{name}"
        end
      end

      command "DROP CLASS #{name}"
    end

    ###
    # Creates a new property in the schema.
    # You need to create the class before.
    def create_property(clazz, property, type, options={})
      raise ArgumentError, "class name is blank" if blank?(clazz)
      raise ArgumentError, "property name is blank" if blank?(property)
      opt_pattern = {
        :mandatory => :optional , :notnull => :optional, :min => :optional, :max => :optional,
        :regexp =>  :optional, :custom => :optional
      }
      verify_options(options, opt_pattern)

      cmd = "CREATE PROPERTY #{clazz}.#{property} #{type.to_s}"
      command cmd, :http_code_500 => 'failed to create property (exists already?)'

      unless options.empty?
        options.each do |k,v|
          command "ALTER PROPERTY #{clazz}.#{property} #{k.to_s.upcase} #{v}"
        end
      end
    end

    protected

      ###
      # Asserts if the client is connected and raises an error if not.
      def assert_connected
        raise OrientdbError, "not connected" unless @connected
      end

      ###
      # Around advice to meassure and print the method time.
      def time_around(&block)
        start = Time.now
        rslt = block.call
        Orientdb4r::logger.debug \
          "#{aop_context[:class].name}##{aop_context[:method]}: elapsed time = #{Time.now - start} [s]"
        rslt
      end

  end

end
