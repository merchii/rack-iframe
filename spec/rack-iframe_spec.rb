require 'spec_helper'

# == References:
#   - http://tempe.st/tag/ruby-on-rails
#   - http://groups.google.com/group/rack-devel/browse_thread/thread/11da5971522b107b
#   - http://grack.com/blog/2010/01/06/3rd-party-cookies-dom-storage-and-privacy
#   - http://anantgarg.com/2010/02/18/cross-domain-cookies-in-safari

describe Rack::Iframe do

  describe "VERSION" do
    it 'should be defined' do
      defined?(::Rack::Iframe::VERSION)
    end

    it 'should be a valid version string (e.g. "0.0.1", or "0.0.1.rc1")' do
      valid_version_string = /^\d+\.\d+\.\d+/
      Rack::Iframe::VERSION.must_match valid_version_string
    end
  end

  describe "Middleware" do
    before do
      @app = CachedApp.new
    end

    describe "without Rack::Iframe" do
      before do
        @user_agents = all_user_agents
      end

      it 'should not have P3P headers' do
        @user_agents.each do |user_agent|
          request = mock_request(user_agent)

          response = @app.call(request)
          status, headers, body = response

          headers.key?('P3P').must_equal false
        end
      end
    end

    describe "with Rack::Iframe" do
      describe "browsers that require the P3P header: IE, Safari" do
        before do
          @user_agents = [:ie, :safari]
        end

        describe "without any HTTP-cache headers" do
          it 'should send P3P header - modified (200 OK)' do
            @user_agents.each do |user_agent|
              request = mock_request(user_agent)

              response = Rack::Iframe.new(@app).call(request)
              status, headers, body = response

              headers['P3P'].must_equal %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV")
              status.must_equal 200 # modified
            end
          end
        end

        # NOTE: P3P headers with HTTP-cache headers don't work well.

        describe "with HTTP-cache headers" do
          describe "If-None-Match (Etag)" do
            it 'should send P3P header - modified (200 OK)' do
              @user_agents.each do |user_agent|
                @app = mock_app('Etag' => '123')

                request = mock_request(user_agent, 'HTTP_IF_NONE_MATCH' => '123')

                response = Rack::Iframe.new(@app).call(request)
                status, headers, body = response

                headers['P3P'].must_equal %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV")
                status.must_equal 200 # modified
              end
            end
          end

          describe "Last-Modified" do
            it 'should send P3P header - modified (200 OK)' do
              skip
              # @user_agents.each do |user_agent|
              #   @app = mock_app('Last-Modified' => Chronic.parse('0 minutes ago').rfc2822)

              #   request = mock_request(user_agent, 'HTTP_IF_MODIFIED_SINCE' => Chronic.parse('1 minute ago').rfc2822)

              #   response = Rack::Iframe.new(@app).call(request)
              #   status, headers, body = response

              #   headers['P3P'].must_equal %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV")
              #   status.must_equal 200 # modified
              # end
            end
          end
        end

        describe "custom middleware-arguments" do
          it 'should use custom P3P header if specified via options as :p3p' do
            request = mock_request(:ie)

            response = Rack::Iframe.new(@app, :p3p => %(CP="NOI DSP LAW NID")).call(request)
            status, headers, body = response

            headers['P3P'].must_equal %(CP="NOI DSP LAW NID")
          end

          it 'should force sending the P3P header if specified via options as :always_send' do
            request = mock_request(:firefox)

            response = Rack::Iframe.new(@app, :always_send => true).call(request)
            status, headers, body = response

            headers['P3P'].must_equal %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV")
          end
        end
      end

      describe "browsers that don't require the P3P header: Chrome, Firefox, Opera" do
        before do
          @user_agents = all_user_agents - [:ie, :safari]
        end

        describe "without any HTTP-cache headers" do
          it 'should not send P3P header - modified (200 OK)' do
            @user_agents.each do |user_agent|
              @app = mock_app()

              request = mock_request(user_agent)

              response = Rack::Iframe.new(@app).call(request)
              status, headers, body = response

              headers.key?('P3P').must_equal false
              status.must_equal 200 # modified
            end
          end
        end

        describe "with HTTP-cache headers" do
          describe "If-None-Match (Etag)" do
            it 'should not send P3P header - not modified (304 Not Modified)' do
              @user_agents.each do |user_agent|
                @app = mock_app('Etag' => '123')

                request = mock_request(user_agent, 'HTTP_IF_NONE_MATCH' => '123')

                response = Rack::Iframe.new(@app).call(request)
                status, headers, body = response

                headers.key?('P3P').must_equal false
                status.must_equal 304 # not modified

                # browser = Rack::Test::Session.new(Rack::MockSession.new(CachedApp))
                # browser.get '/', {}, 'HTTP_IF_NONE_MATCH' => '123'

                # browser.last_response.headers.key?('P3P').must_equal false
                # browser.last_response.status.must_equal 304
              end
            end
          end

          describe "Last-Modified" do
            it 'should not send P3P header - not modified (304 Not Modified)' do
              skip
              # @user_agents.each do |user_agent|
              #   @app = mock_app('Last-Modified' => Chronic.parse('1 minute ago').rfc2822)

              #   request = mock_request(user_agent, 'HTTP_IF_MODIFIED_SINCE' => Chronic.parse('0 minutes ago').rfc2822)

              #   response = Rack::Iframe.new(@app).call(request)
              #   status, headers, body = response

              #   ap headers
              #   headers.key?('P3P').must_equal false
              #   status.must_equal 304 # not modified

              #   # response = Rack::Iframe.new(@app).call(request)
              #   # status, headers, body = response

              #   # ap headers
              #   # headers.key?('P3P').must_equal false
              #   # status.must_equal 304 # not modified

              #   # browser = Rack::Test::Session.new(Rack::MockSession.new(CachedApp))
              #   # browser.get '/', {}, 'HTTP_IF_MODIFIED_SINCE' => Chronic.parse('1 minute ago')

              #   # browser.last_response.headers.key?('P3P').must_equal false
              #   # browser.last_response.status.must_equal 200
              # end
            end
          end
        end
      end

      describe "any browser: Iframe session cookie hack" do
        before do
          @user_agents = [:safari]
        end

        it 'should respond to * /iframe_session with P3P header - modified (200 OK)' do
          @user_agents.each do |user_agent|
            request = mock_request(user_agent, {}, '/iframe_session')

            response = Rack::Iframe.new(@app).call(request)
            status, headers, body = response

            headers['P3P'].must_equal %(CP="ALL DSP COR CURa ADMa DEVa OUR IND COM NAV")
            status.must_equal 200 # modified
          end
        end

        it 'should set session variable :iframe_session on request to /iframe_session' do
          @user_agents.each do |user_agent|
            browser = Rack::Test::Session.new(Rack::MockSession.new(SessionIframeApp))
            browser.get '/iframe_session', {}, 'HTTP_USER_AGENT' => user_agent_string(user_agent)
            browser.get '/test_iframe_session', {}, 'HTTP_USER_AGENT' => user_agent_string(user_agent)
            browser.last_response.body.must_equal "true"
          end
        end
      end
    end
  end
end
