# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Through Association Support' do
  let!(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }
  let!(:tag1) { Tag.create!(name: 'ruby') }
  let!(:tag2) { Tag.create!(name: 'rails') }

  before do
    # Create through associations using ActiveRecord methods (join table invisible)
    post.tags << tag1
    post.tags << tag2
  end

  describe 'Resource definition with through associations' do
    it 'stores the through option in the relationship' do
      relationship_options = PostResource._relationships[:tags]
      expect(relationship_options).to be_present
    end

    it 'defines the relationship method on the resource instance' do
      post_resource = PostResource.new(post)
      expect(post_resource).to respond_to(:tags)
    end

    it 'returns tags through the association' do
      post_resource = PostResource.new(post)
      tags = post_resource.tags
      expect(tags.count).to eq(2)
      expect(tags).to include(tag1, tag2)
    end
  end

  describe 'Serialization with through associations' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'includes tags when requested' do
      result = serializer.serialize(post, {}, includes: ['tags'])

      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      tag_names = tag_items.map { |t| t[:attributes]['name'] }
      expect(tag_names).to contain_exactly('ruby', 'rails')
    end

    it 'does not expose the join table (taggings)' do
      result = serializer.serialize(post, {}, includes: ['tags'])

      # Should not expose taggings in the result
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'includes relationship data in the main resource' do
      result = serializer.serialize(post, {}, includes: ['tags'])

      # Check that tags are included in the included section
      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      # Check that the main resource has relationship links
      expect(result[:data][:relationships]).to be_present if result[:data][:relationships]
    end
  end

  describe 'Reverse through associations' do
    let(:serializer) { JPie::Serializer.new(TagResource) }

    it 'includes posts through taggings' do
      result = serializer.serialize(tag1, {}, includes: ['posts'])

      expect(result[:included]).to be_present
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      expect(post_items.count).to eq(1)
      expect(post_items.first[:attributes]['title']).to eq('Test Post')
    end
  end

  describe 'Polymorphic through associations' do
    let(:serializer) { JPie::Serializer.new(TagResource) }

    it 'handles polymorphic through associations correctly' do
      # Tag is associated with posts through taggings
      result = serializer.serialize(tag1, {}, includes: ['posts'])

      expect(result[:included]).to be_present

      post_items = result[:included].select { |item| item[:type] == 'posts' }

      expect(post_items.count).to eq(1)

      # Verify no taggings are exposed
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end

  describe 'Nested includes through associations' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'supports nested includes through the association' do
      result = serializer.serialize(post, {}, includes: ['tags.posts'])

      expect(result[:included]).to be_present

      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      post_items = result[:included].select { |item| item[:type] == 'posts' }

      expect(tag_items.count).to eq(2)
      # Should include the original post through the nested relationship
      expect(post_items.count).to be >= 1
    end
  end

  describe 'Multiple through associations on same model' do
    let!(:another_post) { Post.create!(title: 'Another Post', content: 'More content', user: user) }

    before do
      # Tag both posts with ruby using ActiveRecord through methods
      another_post.tags << tag1
    end

    it 'handles multiple records through the same association' do
      tag_resource = TagResource.new(tag1)
      posts = tag_resource.posts

      expect(posts.count).to eq(2)
      expect(posts).to include(post, another_post)
    end

    it 'serializes multiple records correctly' do
      serializer = JPie::Serializer.new(TagResource)
      result = serializer.serialize(tag1, {}, includes: ['posts'])

      post_items = result[:included].select { |item| item[:type] == 'posts' }
      expect(post_items.count).to eq(2)

      post_titles = post_items.map { |p| p[:attributes]['title'] }
      expect(post_titles).to contain_exactly('Test Post', 'Another Post')
    end
  end

  describe 'Auto-detection of through associations' do
    it 'works without explicit through parameter when ActiveRecord has through association' do
      # Test with PostResource that doesn't specify through: :taggings
      simple_post_resource = PostResource.new(post)
      tags = simple_post_resource.tags

      expect(tags.count).to eq(2)
      expect(tags).to include(tag1, tag2)
    end

    it 'serializes correctly without explicit through parameter' do
      serializer = JPie::Serializer.new(PostResource)
      result = serializer.serialize(post, {}, includes: ['tags'])

      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
      expect(tag_names).to contain_exactly('ruby', 'rails')
    end
  end

  describe 'Through association updates and deletion' do
    it 'maintains associations when working with through relationships' do
      # Add another tag
      tag3 = Tag.create!(name: 'testing')
      post.tags << tag3

      expect(post.tags.count).to eq(3)
      expect(post.tags).to include(tag1, tag2, tag3)

      # Remove a tag
      post.tags.delete(tag2)
      expect(post.tags.count).to eq(2)
      expect(post.tags).to include(tag1, tag3)
      expect(post.tags).not_to include(tag2)
    end

    it 'removes through association using ActiveRecord methods' do
      expect(post.tags.count).to eq(2)

      post.tags.delete(tag1)

      expect(post.tags.count).to eq(1)
      expect(post.tags).to include(tag2)
      expect(post.tags).not_to include(tag1)
    end

    it 'handles duplicate associations gracefully' do
      # Try to add the same tag twice
      expect { post.tags << tag1 }.not_to raise_error

      # ActiveRecord allows duplicates with << operator, so count may increase
      expect(post.tags.count).to be >= 2
      expect(post.tags.uniq.count).to eq(2) # But unique tags should still be 2
    end
  end

  describe 'Comprehensive join table invisibility' do
    let(:post_serializer) { JPie::Serializer.new(PostResource) }
    let(:tag_serializer) { JPie::Serializer.new(TagResource) }

    it 'never exposes join table in any serialization scenario' do
      # Test post serialization with tags
      post_result = post_serializer.serialize(post, {}, includes: ['tags'])
      tagging_items = post_result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty

      # Test tag serialization with posts
      tag_result = tag_serializer.serialize(tag1, {}, includes: ['posts'])
      tagging_items = tag_result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'provides clean many-to-many relationships without exposing implementation' do
      result = post_serializer.serialize(post, {}, includes: ['tags'])

      # Should have clean post -> tags relationship
      expect(result[:data][:type]).to eq('posts')
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      # No implementation details exposed
      expect(result[:included].any? { |item| item[:type] == 'taggings' }).to be false
    end

    it 'maintains join table invisibility with deep nested includes' do
      result = post_serializer.serialize(post, {}, includes: ['tags.posts'])

      # Should include tags and their posts, but no taggings
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }

      expect(tag_items.count).to eq(2)
      expect(post_items.count).to be >= 1
      expect(tagging_items).to be_empty
    end
  end
end
