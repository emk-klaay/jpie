# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_dispatch'

RSpec.describe JPie::Routing do
  let(:routes) { ActionDispatch::Routing::RouteSet.new }
  let(:mapper) { ActionDispatch::Routing::Mapper.new(routes) }

  before do
    # Include the JPie::Routing module in the mapper
    mapper.singleton_class.include(described_class)
  end

  describe '#jpie_resources' do
    it 'creates routes with JSON format defaults' do
      mapper.jpie_resources :posts

      # Check that routes were created
      expect(routes.routes).not_to be_empty

      # Find the index route
      index_route = routes.routes.find { |route| route.verb == 'GET' && route.path.spec.to_s.include?('/posts') }
      expect(index_route).not_to be_nil

      # Check that the route has JSON format constraints and defaults
      expect(index_route.defaults[:format]).to eq(:json)
      expect(index_route.requirements[:format]).to eq(:json)
    end

    it 'creates JSON:API relationship routes' do
      mapper.jpie_resources :posts

      # Check for relationship routes (e.g., /posts/:id/relationships/*)
      relationship_routes = routes.routes.select do |route|
        route.path.spec.to_s.include?('/posts/:id/relationships/')
      end
      expect(relationship_routes).not_to be_empty

      # Should have GET, PATCH, POST, DELETE for relationships
      relationship_verbs = relationship_routes.map(&:verb).uniq.sort
      expect(relationship_verbs).to include('GET', 'PATCH', 'POST', 'DELETE')

      # Check for related resource routes (e.g., /posts/:id/*)
      related_routes = routes.routes.select do |route|
        route.path.spec.to_s.match?(%r{/posts/:id/[^/]+$}) && route.path.spec.to_s.exclude?('relationships')
      end
      expect(related_routes).not_to be_empty

      # Related routes should only have GET
      related_verbs = related_routes.map(&:verb).uniq
      expect(related_verbs).to eq(['GET'])
    end

    it 'accepts additional options' do
      mapper.jpie_resources :posts, only: %i[index show]

      # Should only create index and show routes
      post_routes = routes.routes.select { |route| route.path.spec.to_s.include?('/posts') }

      # Should have index and show routes (GET requests)
      get_routes = post_routes.select { |route| route.verb == 'GET' }
      expect(get_routes.length).to eq(2)

      # Should not have create, update, or destroy routes
      post_routes_verb = post_routes.select { |route| route.verb == 'POST' }
      patch_routes = post_routes.select { |route| route.verb == 'PATCH' }
      delete_routes = post_routes.select { |route| route.verb == 'DELETE' }

      expect(post_routes_verb).to be_empty
      expect(patch_routes).to be_empty
      expect(delete_routes).to be_empty
    end

    it 'accepts a block for nested routes' do
      mapper.jpie_resources :posts do
        mapper.jpie_resources :comments
      end

      # Check that nested routes were created
      comment_routes = routes.routes.select do |route|
        route.path.spec.to_s.include?('/posts') && route.path.spec.to_s.include?('/comments')
      end
      expect(comment_routes).not_to be_empty

      # Check that nested routes also have JSON format constraints
      comment_route = comment_routes.first
      expect(comment_route.requirements[:format]).to eq(:json)
      expect(comment_route.defaults[:format]).to eq(:json)

      # Verify that both parent and nested resources have relationship routes
      post_relationship_routes = routes.routes.select do |route|
        route.path.spec.to_s.include?('/posts/:id/relationships/')
      end
      expect(post_relationship_routes).not_to be_empty

      comment_relationship_routes = routes.routes.select do |route|
        route.path.spec.to_s.include?('/comments/:id/relationships/')
      end
      expect(comment_relationship_routes).not_to be_empty
    end

    it 'allows overriding default options' do
      mapper.jpie_resources :posts, defaults: { format: :xml }

      # Find a route
      route = routes.routes.find { |route| route.path.spec.to_s.include?('/posts') }

      # Should use the overridden format
      expect(route.defaults[:format]).to eq(:xml)
      # But requirements should still be JSON (merged, not overridden)
      expect(route.requirements[:format]).to eq(:json)
    end

    it 'works with multiple resources' do
      mapper.jpie_resources :posts, :comments

      # Check that routes for both resources were created
      post_routes = routes.routes.select { |route| route.path.spec.to_s.include?('/posts') }
      comment_routes = routes.routes.select { |route| route.path.spec.to_s.include?('/comments') }

      expect(post_routes).not_to be_empty
      expect(comment_routes).not_to be_empty

      # Both should have JSON format constraints
      post_route = post_routes.first
      comment_route = comment_routes.first

      expect(post_route.requirements[:format]).to eq(:json)
      expect(comment_route.requirements[:format]).to eq(:json)
    end
  end
end
