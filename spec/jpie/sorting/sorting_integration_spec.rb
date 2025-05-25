# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'
require 'active_record'

RSpec.describe 'JPie Sorting Integration' do
  let(:controller_class) { create_test_controller('PostsController') }
  let(:controller) { controller_class.new }
  
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post_alpha) { Post.create!(title: 'Alpha Post', content: 'First content', user: user) }
  let!(:post_beta) { Post.create!(title: 'Beta Post', content: 'Second content', user: user) }
  let!(:post_gamma) { Post.create!(title: 'Gamma Post', content: 'Third content', user: user) }

  describe 'Basic sorting functionality' do
    it 'sorts posts by title in ascending order' do
      controller.params = { sort: 'title' }
      controller.index

      result = controller.last_render[:json]
      titles = result[:data].map { |post| post[:attributes]['title'] }
      
      expect(titles).to eq(['Alpha Post', 'Beta Post', 'Gamma Post'])
    end

    it 'sorts posts by title in descending order' do
      controller.params = { sort: '-title' }
      controller.index

      result = controller.last_render[:json]
      titles = result[:data].map { |post| post[:attributes]['title'] }
      
      expect(titles).to eq(['Gamma Post', 'Beta Post', 'Alpha Post'])
    end

    it 'handles multiple sort fields' do
      # Create posts with same title but different content
      Post.create!(title: 'Same Title', content: 'AAA Content', user: user)
      Post.create!(title: 'Same Title', content: 'ZZZ Content', user: user)

      controller.params = { sort: 'title,content' }
      controller.index

      result = controller.last_render[:json]
      
      # Should sort by title first, then by content
      same_title_posts = result[:data].select { |post| post[:attributes]['title'] == 'Same Title' }
      contents = same_title_posts.map { |post| post[:attributes]['content'] }
      
      expect(contents).to eq(['AAA Content', 'ZZZ Content'])
    end

    it 'handles mixed ascending and descending sort' do
      controller.params = { sort: 'title,-content' }
      controller.index

      result = controller.last_render[:json]
      
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to be >= 3
    end
  end

  describe 'Sort parameter validation' do
    it 'handles empty sort parameter gracefully' do
      controller.params = { sort: '' }
      
      expect { controller.index }.not_to raise_error
      
      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
    end

    it 'handles missing sort parameter' do
      controller.params = {}
      
      expect { controller.index }.not_to raise_error
      
      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
    end

    it 'handles whitespace in sort parameter' do
      controller.params = { sort: ' title , content ' }
      
      expect { controller.index }.not_to raise_error
      
      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
    end
  end

  describe 'Sort with includes' do
    it 'sorts and includes related resources' do
      controller.params = { sort: 'title', include: 'user' }
      controller.index

      result = controller.last_render[:json]
      
      # Should be sorted
      titles = result[:data].map { |post| post[:attributes]['title'] }
      expect(titles).to eq(['Alpha Post', 'Beta Post', 'Gamma Post'])
      
      # Should include user
      expect(result).to have_key(:included)
      user_data = result[:included].find { |item| item[:type] == 'users' }
      expect(user_data).to be_present
    end

    it 'maintains sort order with complex includes' do
      controller.params = { sort: '-title', include: 'user,comments' }
      controller.index

      result = controller.last_render[:json]
      
      titles = result[:data].map { |post| post[:attributes]['title'] }
      expect(titles).to eq(['Gamma Post', 'Beta Post', 'Alpha Post'])
    end
  end

  describe 'Sort with pagination' do
    it 'handles pagination parameters without error' do
      controller.params = { sort: 'title', page: { number: '1', size: '5' } }
      
      expect { controller.index }.not_to raise_error
      
      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
    end
  end

  describe 'Error handling' do
    it 'raises error for invalid sort fields' do
      controller.params = { sort: 'invalid_field' }
      
      expect { controller.index }.to raise_error(JPie::Errors::UnsupportedSortFieldError)
    end

    it 'raises error for malformed sort parameters' do
      controller.params = { sort: ',,invalid,,' }
      
      expect { controller.index }.to raise_error(JPie::Errors::UnsupportedSortFieldError)
    end
  end

  describe 'Performance considerations' do
    it 'handles large datasets efficiently' do
      # Create a larger dataset
      50.times do |i|
        Post.create!(title: "Performance Post #{i}", content: "Content #{i}", user: user)
      end

      start_time = Time.current
      
      controller.params = { sort: 'title' }
      controller.index
      
      end_time = Time.current
      
      # Should complete within reasonable time (adjust threshold as needed)
      expect(end_time - start_time).to be < 1.0
      
      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to be >= 50
    end
  end
end



