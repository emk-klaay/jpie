# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'
require 'active_record'

RSpec.describe 'Sorting Integration' do
  let!(:alice) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:bob) { User.create!(name: 'Bob', email: 'bob@example.com') }
  let!(:charlie) { User.create!(name: 'Charlie', email: 'charlie@example.com') }

  let(:controller) do
    Class.new(ApplicationController) do
      include JPie::Controller

      def self.name
        'UsersController'
      end

      attr_accessor :params, :request, :response

      def initialize
        @params = {}
        @request = MockRequest.new
        @response = MockResponse.new
      end

      def render(options = {})
        @last_render = options
      end

      def action_name
        'index'
      end

      attr_reader :last_render
    end.new
  end

  before do
    # Define mock classes
    stub_const('MockRequest', Class.new do
      def body
        MockBody.new
      end
    end)

    stub_const('MockBody', Class.new do
      def read
        '{}'
      end
    end)

    stub_const('MockResponse', Class.new)
  end

  describe 'basic sorting' do
    it 'sorts users by name ascending' do
      controller.params = { sort: 'name' }
      controller.index

      data = controller.last_render[:json][:data]
      names = data.map { |user| user[:attributes]['name'] }
      expect(names).to eq(%w[Alice Bob Charlie])
    end

    it 'sorts users by name descending' do
      controller.params = { sort: '-name' }
      controller.index

      data = controller.last_render[:json][:data]
      names = data.map { |user| user[:attributes]['name'] }
      expect(names).to eq(%w[Charlie Bob Alice])
    end

    it 'sorts users by email ascending' do
      controller.params = { sort: 'email' }
      controller.index

      data = controller.last_render[:json][:data]
      emails = data.map { |user| user[:attributes]['email'] }
      expect(emails).to eq(['alice@example.com', 'bob@example.com', 'charlie@example.com'])
    end
  end

  describe 'multiple field sorting' do
    let!(:alice2) { User.create!(name: 'Alice', email: 'alice2@example.com') }

    it 'sorts by multiple fields' do
      controller.params = { sort: 'name,email' }
      controller.index

      data = controller.last_render[:json][:data]
      user_info = data.map { |user| [user[:attributes]['name'], user[:attributes]['email']] }

      expect(user_info).to eq([
                                ['Alice', 'alice2@example.com'],
                                ['Alice', 'alice@example.com'],
                                ['Bob', 'bob@example.com'],
                                ['Charlie', 'charlie@example.com']
                              ])
    end

    it 'sorts by name ascending and email descending' do
      controller.params = { sort: 'name,-email' }
      controller.index

      data = controller.last_render[:json][:data]
      user_info = data.map { |user| [user[:attributes]['name'], user[:attributes]['email']] }

      expect(user_info).to eq([
                                ['Alice', 'alice@example.com'],
                                ['Alice', 'alice2@example.com'],
                                ['Bob', 'bob@example.com'],
                                ['Charlie', 'charlie@example.com']
                              ])
    end
  end

  describe 'error handling' do
    it 'raises error for invalid sort field' do
      controller.params = { sort: 'invalid_field' }

      expect { controller.index }.to raise_error(
        JPie::Errors::BadRequestError,
        /Invalid sort field: invalid_field/
      )
    end

    it 'includes available fields in error message' do
      controller.params = { sort: 'invalid_field' }

      expect { controller.index }.to raise_error(
        JPie::Errors::BadRequestError,
        /Sortable fields are: name, email/
      )
    end
  end

  describe 'custom sortable fields' do
    let(:custom_resource_class) do
      Class.new(JPie::Resource) do
        model User
        attributes :name, :email

        # Add a custom sortable field
        sortable_by :reverse_name do |query, direction|
          if direction == :asc
            query.order('name DESC')
          else
            query.order('name ASC')
          end
        end

        def self.name
          'CustomUserResource'
        end
      end
    end

    let(:custom_controller) do
      resource_class = custom_resource_class
      Class.new(ApplicationController) do
        include JPie::Controller

        define_method :resource_class do
          resource_class
        end

        def self.name
          'CustomUsersController'
        end

        attr_accessor :params, :request, :response

        def initialize
          @params = {}
          @request = MockRequest.new
          @response = MockResponse.new
        end

        def render(options = {})
          @last_render = options
        end

        def action_name
          'index'
        end

        attr_reader :last_render
      end.new
    end

    it 'uses custom sorting logic' do
      custom_controller.params = { sort: 'reverse_name' }
      custom_controller.index

      data = custom_controller.last_render[:json][:data]
      names = data.map { |user| user[:attributes]['name'] }
      # reverse_name with asc direction should sort by name DESC
      expect(names).to eq(%w[Charlie Bob Alice])
    end

    it 'reverses custom sorting with descending direction' do
      custom_controller.params = { sort: '-reverse_name' }
      custom_controller.index

      data = custom_controller.last_render[:json][:data]
      names = data.map { |user| user[:attributes]['name'] }
      # reverse_name with desc direction should sort by name ASC
      expect(names).to eq(%w[Alice Bob Charlie])
    end
  end

  describe 'no sorting' do
    it 'returns users without sorting when no sort parameter' do
      controller.params = {}
      controller.index

      data = controller.last_render[:json][:data]
      expect(data).to be_an(Array)
      expect(data.length).to eq(3)
    end

    it 'returns users without sorting when sort parameter is empty' do
      controller.params = { sort: '' }
      controller.index

      data = controller.last_render[:json][:data]
      expect(data).to be_an(Array)
      expect(data.length).to eq(3)
    end
  end
end
