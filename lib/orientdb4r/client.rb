module Orientdb4r

  class Client
    include Utils

    # Server version used if no concrete version identified.
    DEFAULT_SERVER_VERSION = '1.0.0--'

    SERVER_VERSION_PATTERN = /^\d+\.\d+\.\d+/

    attr_reader :server_version

    ###
    # Constructor.
    def initialize
      @connected = false
    end


    # --------------------------------------------------------------- CONNECTION

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
    # Retrieve information about the connected OrientDB Server.
    # Enables additional authentication to the server with an account
    # that can access the 'server.info' resource.
    def server(options={})
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    # ----------------------------------------------------------------- DATABASE

    ###
    # Creates a new database.
    # You can provide an additional authentication to the server with 'database.create' resource
    # or the current one will be used.
    def create_database(options)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Retrieves all the information about a database.
    # Client has not to be connected to see databases suitable to connect.
    def get_database(name_or_options)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Checks existence of a given database.
    # Client has not to be connected to see databases suitable to connect.
    def database_exists?(name_or_options)
      rslt = true
      begin
        get_database name_or_options
      rescue NotFoundError
        rslt = false
      end
      rslt
    end


    # ---------------------------------------------------------------------- SQL

    ###
    # Executes a query against the database.
    def query(sql, options)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Executes a command against the database.
    def command(sql)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    # -------------------------------------------------------------------- CLASS

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

      command sql

      if block_given?
        proxy = Orientdb4r::Utils::Proxy.new(self, name)
        def proxy.property(property, type, options={})
          self.target.send :create_property, self.context, property, type, options
        end
        def proxy.link(property, type, linked_class, options={})
          raise ArgumentError, "type has to be a linked-type, given=#{type}" unless type.to_s.start_with? 'link'
          options[:linked_class] = linked_class
          self.target.send :create_property, self.context, property, type, options
        end
        yield proxy
      end
    end


    ###
    # Gets informations about requested class.
    def get_class(name)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Removes a class from the schema.
    def drop_class(name, options={})
      raise ArgumentError, "class name is blank" if blank?(name)

      # :mode=>:strict forbids to drop a class that is a super class for other one
      opt_pattern = { :mode => :nil }
      verify_options(options, opt_pattern)
      if :strict == options[:mode]
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
        :regexp =>  :optional, :custom => :optional, :linked_class => :optional
      }
      verify_options(options, opt_pattern)

      cmd = "CREATE PROPERTY #{clazz}.#{property} #{type.to_s}"
      # link?
      if [:link, :linklist, :linkset, :linkmap].include? type.to_s.downcase.to_sym
        raise ArgumentError, "defined linked-type, but not linked-class" unless options.include? :linked_class
        cmd << " #{options[:linked_class]}"
      end
      command cmd

      # ALTER PROPERTY ...
      options.delete :linked_class # it's not option for ALTER
      unless options.empty?
        options.each do |k,v|
          command "ALTER PROPERTY #{clazz}.#{property} #{k.to_s.upcase} #{v}"
        end
      end
    end


    # ----------------------------------------------------------------- DOCUMENT

    ###
    # Create a new document.
    # Returns the Record-id assigned.
    def create_document(doc)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Retrieves a document by given ID.
    def get_document(rid)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Updates an existing document.
    def update_document(doc)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    ###
    # Deletes an existing document.
    def delete_document(rid)
      raise NotImplementedError, 'this should be overridden by concrete client'
    end


    protected

      ###
      # Asserts if the client is connected and raises an error if not.
      def assert_connected
        raise ConnectionError, 'not connected' unless @connected
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
