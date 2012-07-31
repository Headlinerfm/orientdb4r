require 'excon'

module Orientdb4r

  ###
  # This class represents a single sever/node in the Distributed Multi-Master Architecture
  # accessible view REST API and 'excon' library on the client side.
  class ExconNode < RestNode

    def one_off_request(options) #:nodoc:
      address = "#{url}/#{options[:uri]}"
      headers = {}
      headers['Authorization'] = basic_auth_header(options[:user], options[:password]) if options.include?(:user)
      headers['Cookie'] = "#{SESSION_COOKIE_NAME}=#{session_id}" unless session_id.nil?
      response = ::Excon.send options[:method].to_sym, address, :headers => headers

      def response.code
        status
      end

      response
    end


    def request(options) #:nodoc:
      verify_options(options, {:user => :mandatory, :password => :mandatory, \
          :uri => :mandatory, :method => :mandatory, :content_type => :optional, :data => :optional})

      opts = options.clone # if not cloned we change original hash map that cannot be used more with load balancing

      # Auth + Cookie + Content-Type
      opts[:headers] = headers(opts)
      opts.delete :user
      opts.delete :password

      opts[:body] = opts[:data] if opts.include? :data # just other naming convention
      opts.delete :data
      opts[:path] = opts[:uri] if opts.include? :uri   # just other naming convention
      opts.delete :uri

      response = connection.request opts

      # store session ID if received to reuse in next request
      cookies = CGI::Cookie::parse(response.headers['Set-Cookie'])
      sessid = cookies[SESSION_COOKIE_NAME][0]
      if session_id != sessid
        @session_id = sessid
        Orientdb4r::logger.debug "new session id: #{session_id}"
      end


      def response.code
        status
      end

      response
    end


    def post_connect(user, password, http_response) #:nodoc:

      cookies = CGI::Cookie::parse(http_response.headers['Set-Cookie'])
      @session_id = cookies[SESSION_COOKIE_NAME][0]

    end


    def cleanup #:nodoc:
      super
      connection.reset
      @connection = nil
    end


    # ---------------------------------------------------------- Assistant Stuff

    private

      ###
      # Gets Excon connection.
      def connection
        @connection ||= Excon::Connection.new(url)
          #:read_timeout => self.class.read_timeout,
          #:write_timeout => self.class.write_timeout,
          #:connect_timeout => self.class.connect_timeout
      end

      ###
      # Get request headers prepared with session ID and Basic Auth.
      def headers(options)
        rslt = {'Authorization' => basic_auth_header(options[:user], options[:password])}
        rslt['Cookie'] = "#{SESSION_COOKIE_NAME}=#{session_id}" unless session_id.nil?
        rslt['Content-Type'] = options[:content_type] if options.include? :content_type
        rslt
      end

      ###
      # Gets value of the Basic Auth header.
      def basic_auth_header(user, password)
        b64 = Base64.encode64("#{user}:#{password}").delete("\r\n")
        "Basic #{b64}"
      end

  end

end
