# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'

RSpec.describe 'JPie Pagination Support' do
  let(:controller_class) { create_test_controller('PostsController') }
  let(:controller) { controller_class.new }

  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }

  before do
    # Create test data for pagination
    20.times do |i|
      Post.create!(title: "Post #{i + 1}", content: "Content #{i + 1}", user: user)
    end
  end

  describe 'Basic pagination functionality' do
    it 'returns paginated results with page and per_page parameters' do
      controller.params = { page: '1', per_page: '5' }
      controller.index

      result = controller.last_render[:json]

      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(5)
      expect(result).to have_key(:meta)
      expect(result[:meta]).to have_key(:pagination)
    end

    it 'includes correct pagination metadata' do
      controller.params = { page: '2', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(2)
      expect(pagination[:per_page]).to eq(5)
      expect(pagination[:total_count]).to eq(20)
      expect(pagination[:total_pages]).to eq(4)
    end

    it 'includes pagination links' do
      controller.params = { page: '2', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      links = result[:links]

      expect(links).to have_key(:self)
      expect(links).to have_key(:first)
      expect(links).to have_key(:last)
      expect(links).to have_key(:prev)
      expect(links).to have_key(:next)
    end

    it 'includes correct pagination link values' do
      controller.params = { page: '2', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      links = result[:links]

      expect(links[:self]).to include('page=2')
      expect(links[:self]).to include('per_page=5')
      expect(links[:first]).to include('page=1')
      expect(links[:last]).to include('page=4')
      expect(links[:prev]).to include('page=1')
      expect(links[:next]).to include('page=3')
    end

    it 'does not include prev link on first page' do
      controller.params = { page: '1', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      links = result[:links]

      expect(links).not_to have_key(:prev)
      expect(links).to have_key(:next)
    end

    it 'does not include next link on last page' do
      controller.params = { page: '4', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      links = result[:links]

      expect(links).to have_key(:prev)
      expect(links).not_to have_key(:next)
    end
  end

  describe 'JSON:API page parameter format support' do
    it 'supports page[number] and page[size] format' do
      controller.params = { page: { number: '2', size: '3' } }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(2)
      expect(pagination[:per_page]).to eq(3)
      expect(pagination[:total_count]).to eq(20)
      expect(pagination[:total_pages]).to eq(7)
    end

    it 'supports string keys for page parameters' do
      controller.params = { page: { 'number' => '3', 'size' => '4' } }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(3)
      expect(pagination[:per_page]).to eq(4)
    end
  end

  describe 'Parameter validation and defaults' do
    it 'defaults to page 1 when page parameter is missing' do
      controller.params = { per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(1)
    end

    it 'handles invalid page numbers gracefully' do
      controller.params = { page: '0', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(1)
    end

    it 'handles negative page numbers gracefully' do
      controller.params = { page: '-1', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      pagination = result[:meta][:pagination]

      expect(pagination[:page]).to eq(1)
    end

    it 'handles invalid per_page values gracefully' do
      controller.params = { page: '1', per_page: '0' }
      controller.index

      result = controller.last_render[:json]

      # Should not include pagination when per_page is invalid
      expect(result).not_to have_key(:links)
      expect(result[:meta]).to be_nil
    end

    it 'returns all results when no pagination parameters are provided' do
      controller.params = {}
      controller.index

      result = controller.last_render[:json]

      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(20)
      expect(result).not_to have_key(:links)
      expect(result[:meta]).to be_nil
    end
  end

  describe 'Pagination with sorting' do
    it 'maintains sort order with pagination' do
      controller.params = { sort: 'title', page: '1', per_page: '3' }
      controller.index

      result = controller.last_render[:json]
      titles = result[:data].map { |post| post[:attributes]['title'] }

      expect(titles).to eq(['Post 1', 'Post 10', 'Post 11'])
      expect(result[:meta][:pagination][:page]).to eq(1)
    end

    it 'applies pagination after sorting' do
      controller.params = { sort: '-title', page: '2', per_page: '3' }
      controller.index

      result = controller.last_render[:json]
      titles = result[:data].map { |post| post[:attributes]['title'] }

      # Should be sorted descending, then paginated
      expect(titles.length).to eq(3)
      expect(result[:meta][:pagination][:page]).to eq(2)
    end
  end

  describe 'Pagination with includes' do
    it 'includes related resources with pagination' do
      controller.params = { include: 'user', page: '1', per_page: '3' }
      controller.index

      result = controller.last_render[:json]

      expect(result[:data].length).to eq(3)
      expect(result).to have_key(:included)
      expect(result[:included]).to be_an(Array)
      expect(result[:meta][:pagination][:page]).to eq(1)
    end
  end

  describe 'Edge cases' do
    it 'handles empty result sets' do
      Post.destroy_all

      controller.params = { page: '1', per_page: '5' }
      controller.index

      result = controller.last_render[:json]

      expect(result[:data]).to be_an(Array)
      expect(result[:data]).to be_empty
      expect(result[:meta][:pagination][:total_count]).to eq(0)
      expect(result[:meta][:pagination][:total_pages]).to eq(0)
    end

    it 'handles page numbers beyond available pages' do
      controller.params = { page: '100', per_page: '5' }
      controller.index

      result = controller.last_render[:json]

      expect(result[:data]).to be_an(Array)
      expect(result[:data]).to be_empty
      expect(result[:meta][:pagination][:page]).to eq(100)
      expect(result[:meta][:pagination][:total_pages]).to eq(4)
    end

    it 'handles very large per_page values' do
      controller.params = { page: '1', per_page: '1000' }
      controller.index

      result = controller.last_render[:json]

      expect(result[:data].length).to eq(20)
      expect(result[:meta][:pagination][:per_page]).to eq(1000)
      expect(result[:meta][:pagination][:total_pages]).to eq(1)
    end
  end

  describe 'URL generation' do
    it 'generates pagination links correctly' do
      controller.params = { page: '2', per_page: '5' }
      controller.index

      result = controller.last_render[:json]
      links = result[:links]

      expect(links[:self]).to include('page=2')
      expect(links[:self]).to include('per_page=5')
      expect(links[:first]).to include('page=1')
      expect(links[:last]).to include('page=4')
      expect(links[:prev]).to include('page=1')
      expect(links[:next]).to include('page=3')
    end
  end
end
