require 'rack'
require 'rack/iframe/version'
require 'digest/md5'

module Rack
  class Iframe

    DEFAULT_P3P = %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV").freeze
    DEFAULT_IFRAME_SESSION_PATH = '/iframe_session'.freeze
    DEFAULT_ENV_SESSION_KEY = 'rack.session'.freeze

    def initialize(app, options = {})
      @app, @options = app, options
      @options[:p3p] ||= DEFAULT_P3P
      @options[:iframe_session_path] ||= DEFAULT_IFRAME_SESSION_PATH
      @options[:env_session_key] ||= DEFAULT_ENV_SESSION_KEY
    end

    def call(env)
      # 1) If P3P: Set a random Etag (If-None-Match) to trick backend to not send cached response (304).
      set_invalid_etag!(env) if set_p3p_header?(env)

      # 2) Request
      if iframe_session_path?(env)
        @app.call(env) # ...still call app as we want same ENV.
        @status, @headers, @body = iframe_session_response(env)
      else
        @status, @headers, @body = @app.call(env)
      end

      # 3) If P3P: Attach P3P header.
      set_p3p_header! if set_p3p_header?(env)

      # 4) Response
      [@status, @headers, @body]
    end

    protected

      def user_agent(env)
        env['HTTP_USER_AGENT'] || []
      end

      def set_invalid_etag!(env)
        env['HTTP_IF_NONE_MATCH'] = Digest::MD5.hexdigest(Time.now.to_s)
      end

      def set_p3p_header!
        @headers['P3P'] = @options[:p3p]
      end

      def set_p3p_header?(env)
        user_agents?([:ie, :safari], env)
      end

      def user_agent?(id, env)
        case id
        when :ie
          user_agent(env).include?('MSIE')
        when :safari
          user_agent(env).include?('Safari')
        when :opera
          user_agent(env).include?('Chrome')
        when :opera
          user_agent(env).include?('Opera')
        when :firefox
          user_agent(env).include?('Firefox')
        else
          raise "Define missing browser agent: #{id.inspect}"
        end
      end

      def user_agents?(ids, env)
        [*ids].any? do |id|
          user_agent?(id, env)
        end
      end

      def iframe_session_path?(env)
        env['PATH_INFO'] == @options[:iframe_session_path]
      end

      def iframe_session_response(env)
        begin
          # Write a value into the session to ensure we get a session (cookie).
          session_key = @options[:env_session_key]
          env[session_key][:iframe_session] = true
        rescue => e
          env['rack.errors'].puts "[rack-iframe]: env[#{@options[:env_session_key]}] = #{env[@options[:env_session_key]]}"
        end
        [200, {}, [""]]
      end

  end
end
