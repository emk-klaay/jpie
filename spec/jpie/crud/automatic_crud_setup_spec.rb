# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Automatic CRUD Setup' do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }

  describe 'class method setup' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        include JPie::Controller

        attr_accessor :params, :request, :response
        attr_reader :last_render, :last_head

        def initialize
          @params = {}
          @request = MockRequest.new
          @response = MockResponse.new
        end

        def render(options = {})
          @last_render = options
        end

        def head(status)
          @last_head = status
        end

        def action_name
          'test'
        end

        attr_reader :current_user

        attr_writer :current_user

        def self.name
          'AutoSetupController'
        end
      end
    end

    before do
      # Set up mock classes
      stub_const('MockRequest', Class.new do
        attr_accessor :content_type, :method

        def initialize
          @content_type = 'application/vnd.api+json'
          @method = 'GET'
          @body_content = '{}'
        end

        def body
          MockBody.new(@body_content)
        end

        def body=(content)
          @body_content = content
        end

        %w[POST PATCH PUT].each do |http_method|
          define_method("#{http_method.downcase}?") do
            @method == http_method
          end
        end
      end)

      stub_const('MockBody', Class.new do
        def initialize(content = '{}')
          @content = content
          @position = 0
        end

        def read
          result = @content[@position..] || ''
          @position = @content.length
          result
        end

        def rewind
          @position = 0
        end
      end)

      stub_const('MockResponse', Class.new)

      stub_const('ApplicationController', Class.new do
        def self.rescue_from(exception_class, with: nil)
          # Mock implementation for testing
        end

        def head(status)
          # Mock implementation
        end
      end)
    end

    describe '.jsonapi_resource' do
      it 'sets up automatic CRUD methods' do
        # Call the setup method
        controller_class.jsonapi_resource(PostResource)

        controller = controller_class.new
        controller.current_user = user

        # Test that all CRUD methods are defined and work
        expect(controller).to respond_to(:index)
        expect(controller).to respond_to(:show)
        expect(controller).to respond_to(:create)
        expect(controller).to respond_to(:update)
        expect(controller).to respond_to(:destroy)

        # Test that resource_class is set correctly
        expect(controller.resource_class).to eq(PostResource)
      end

      it 'defines working index method' do
        controller_class.jsonapi_resource(PostResource)
        controller = controller_class.new
        controller.current_user = user

        controller.index

        expect(controller.last_render[:json][:data]).to be_an(Array)
        expect(controller.last_render[:status]).to eq(:ok)
      end

      it 'defines working show method' do
        controller_class.jsonapi_resource(PostResource)
        controller = controller_class.new
        controller.current_user = user
        controller.params = { id: post.id.to_s }

        controller.show

        expect(controller.last_render[:json][:data]).to be_a(Hash)
        expect(controller.last_render[:json][:data][:id]).to eq(post.id.to_s)
      end

      it 'defines working create method' do
        controller_class.jsonapi_resource(PostResource)
        controller = controller_class.new
        controller.current_user = user

        create_params = {
          data: {
            type: 'posts',
            attributes: {
              title: 'Auto Created Post',
              content: 'Auto created content'
            }
          }
        }

        controller.request.body = create_params.to_json
        controller.request.method = 'POST'

        expect { controller.create }.to change(Post, :count).by(1)
        expect(controller.last_render[:status]).to eq(:created)
      end

      it 'defines working update method' do
        controller_class.jsonapi_resource(PostResource)
        controller = controller_class.new
        controller.current_user = user
        controller.params = { id: post.id.to_s }

        update_params = {
          data: {
            id: post.id.to_s,
            type: 'posts',
            attributes: {
              title: 'Auto Updated Title'
            }
          }
        }

        controller.request.body = update_params.to_json
        controller.request.method = 'PATCH'

        controller.update

        expect(controller.last_render[:status]).to eq(:ok)
        post.reload
        expect(post.title).to eq('Auto Updated Title')
      end

      it 'defines working destroy method' do
        controller_class.jsonapi_resource(PostResource)
        controller = controller_class.new
        controller.current_user = user
        controller.params = { id: post.id.to_s }

        expect { controller.destroy }.to change(Post, :count).by(-1)
        expect(controller.last_head).to eq(:no_content)
      end
    end

    describe '.resource alias' do
      it 'works as an alias for jsonapi_resource' do
        controller_class.resource(PostResource)
        controller = controller_class.new
        controller.current_user = user

        expect(controller.resource_class).to eq(PostResource)
        expect(controller).to respond_to(:index)
      end
    end
  end
end
