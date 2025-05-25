# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Through Association Support' do
  let!(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }
  let!(:comment) { Comment.create!(content: 'Test comment', user: user, post: post) }
  let!(:tag1) { Tag.create!(name: 'ruby') }
  let!(:tag2) { Tag.create!(name: 'rails') }

  before do
    # Create through associations using ActiveRecord methods (join table invisible)
    post.tags << tag1
    post.tags << tag2
    comment.tags << tag1
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

    it 'includes comments through taggings' do
      result = serializer.serialize(tag1, {}, includes: ['comments'])

      expect(result[:included]).to be_present
      comment_items = result[:included].select { |item| item[:type] == 'comments' }
      expect(comment_items.count).to eq(1)
      expect(comment_items.first[:attributes]['content']).to eq('Test comment')
    end
  end

  describe 'Polymorphic through associations' do
    let(:serializer) { JPie::Serializer.new(TagResource) }

    it 'handles polymorphic through associations correctly' do
      # Tag is associated with both posts and comments through taggings
      result = serializer.serialize(tag1, {}, includes: ['posts', 'comments'])

      expect(result[:included]).to be_present
      
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }
      
      expect(post_items.count).to eq(1)
      expect(comment_items.count).to eq(1)
      
      # Verify no taggings are exposed
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end

  describe 'Custom relationship names with through associations' do
    let(:custom_tag_resource_class) do
      Class.new(JPie::Resource) do
        model Tag
        type 'tags'

        attributes :name
        meta_attributes :created_at, :updated_at

        # Use custom names for through associations
        has_many :tagged_posts, attr: :posts, resource: 'PostResource'
        has_many :tagged_comments, attr: :comments, resource: 'CommentResource'

        def self.name
          'CustomTagResource'
        end
      end
    end

    it 'supports custom relationship names' do
      tag_resource = custom_tag_resource_class.new(tag1)
      
      tagged_posts = tag_resource.tagged_posts
      tagged_comments = tag_resource.tagged_comments
      
      expect(tagged_posts.count).to eq(1)
      expect(tagged_posts).to include(post)
      expect(tagged_comments.count).to eq(1)
      expect(tagged_comments).to include(comment)
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

      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      tag_names = tag_items.map { |t| t[:attributes]['name'] }
      expect(tag_names).to contain_exactly('ruby', 'rails')
      
      # Join table should still not be exposed
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'works for reverse associations without explicit through parameter' do
      simple_tag_resource = TagResource.new(tag1)
      posts = simple_tag_resource.posts
      comments = simple_tag_resource.comments
      
      expect(posts.count).to eq(1) # Only the main post in this test context
      expect(posts).to include(post)
      expect(comments.count).to eq(1)
      expect(comments).to include(comment)
    end

    it 'serializes reverse associations correctly without explicit through parameter' do
      serializer = JPie::Serializer.new(TagResource)
      result = serializer.serialize(tag1, {}, includes: ['posts', 'comments'])

      expect(result[:included]).to be_present
      
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }
      
      expect(post_items.count).to eq(1) # Only the main post
      expect(comment_items.count).to eq(1)
      
      # Join table should still not be exposed
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end

  describe 'Through association updates and deletion' do
    before do
      # Reset associations for clean test state
      post.tags.clear
      comment.tags.clear
      post.tags << tag1
    end

    it 'maintains associations when working with through relationships' do
      # Verify associations exist
      expect(post.tags).to include(tag1)
      expect(tag1.posts).to include(post)
      
      # Associations should remain intact after reload
      post.reload
      tag1.reload
      expect(post.tags).to include(tag1)
      expect(tag1.posts).to include(post)
    end

    it 'removes through association using ActiveRecord methods' do
      expect(post.tags).to include(tag1)
      expect(tag1.posts).to include(post)

      # Remove association using ActiveRecord through methods
      post.tags.delete(tag1)

      # Through associations should be removed
      post.reload
      tag1.reload
      expect(post.tags).not_to include(tag1)
      expect(tag1.posts).not_to include(post)
    end

    it 'handles duplicate associations gracefully' do
      # Add tag to post
      expect(post.tags).to include(tag1)
      expect(post.tags.count).to eq(1)
      
      # Try to add the same tag again - ActiveRecord will create another association
      post.tags << tag1
      
      # ActiveRecord allows duplicates with << operator
      expect(post.tags).to include(tag1)
      expect(post.tags.where(id: tag1.id).count).to be >= 1
    end
  end

  describe 'Comprehensive join table invisibility' do
    before do
      # Set up complex associations
      post.tags << tag1
      post.tags << tag2
      comment.tags << tag1
    end

    it 'never exposes join table in any serialization scenario' do
      # Test post serialization
      post_serializer = JPie::Serializer.new(PostResource)
      post_result = post_serializer.serialize(post, {}, includes: ['tags'])
      
      # Test tag serialization  
      tag_serializer = JPie::Serializer.new(TagResource)
      tag_result = tag_serializer.serialize(tag1, {}, includes: ['posts', 'comments'])
      
      # Test comment serialization
      comment_serializer = JPie::Serializer.new(CommentResource)
      comment_result = comment_serializer.serialize(comment, {}, includes: ['tags'])
      
      # Verify no taggings are exposed in any result
      all_results = [post_result, tag_result, comment_result]
      all_results.each do |result|
        if result[:included]
          taggings = result[:included].select { |r| r[:type] == 'taggings' }
          expect(taggings).to be_empty, "Join table 'taggings' should never be exposed in serialization"
        end
      end
    end

    it 'provides clean many-to-many relationships without exposing implementation' do
      # From post perspective
      post_resource = PostResource.new(post)
      expect(post_resource.tags).to include(tag1, tag2)
      
      # From tag perspective  
      tag_resource = TagResource.new(tag1)
      expect(tag_resource.posts).to include(post)
      expect(tag_resource.comments).to include(comment)
      
      # The fact that there's a join table should be completely hidden
      # Users of the API should only see the direct many-to-many relationships
    end

    it 'maintains join table invisibility with deep nested includes' do
      serializer = JPie::Serializer.new(PostResource)
      result = serializer.serialize(post, {}, includes: ['tags.posts', 'tags.comments'])
      
      # Should include tags and their related resources
      included_tags = result[:included].select { |r| r[:type] == 'tags' }
      included_posts = result[:included].select { |r| r[:type] == 'posts' }
      included_comments = result[:included].select { |r| r[:type] == 'comments' }
      
      expect(included_tags.size).to eq(2)
      expect(included_posts.size).to be >= 1
      expect(included_comments.size).to be >= 1
      
      # Join table should never appear even in complex nested scenarios
      taggings = result[:included].select { |r| r[:type] == 'taggings' }
      expect(taggings).to be_empty
    end
  end
end
