# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Authorization Integration' do
  describe 'resource scoping for authorization' do
    let(:admin_user) { User.create!(name: 'Admin', email: 'admin@example.com') }
    let(:regular_user) { User.create!(name: 'User', email: 'user@example.com') }
    let(:other_user) { User.create!(name: 'Other', email: 'other@example.com') }

    before do
      # Create some posts
      @admin_post = Post.create!(title: 'Admin Post', content: 'Admin content', user: admin_user)
      @user_post = Post.create!(title: 'User Post', content: 'User content', user: regular_user)
      @other_post = Post.create!(title: 'Other Post', content: 'Other content', user: other_user)

      # Add admin? method to users for testing
      admin_user.define_singleton_method(:admin?) { true }
      regular_user.define_singleton_method(:admin?) { false }
      other_user.define_singleton_method(:admin?) { false }
    end

    context 'with a scoped resource class' do
      let(:scoped_post_resource_class) do
        Class.new(JPie::Resource) do
          model Post
          attributes :title, :content
          meta_attributes :created_at, :updated_at
          has_one :user

          def self.scope(context = {})
            current_user = context[:current_user]
            return model.none unless current_user

            # Admins can see all posts, users can only see their own posts
            if current_user.admin?
              model.all
            else
              model.where(user: current_user)
            end
          end

          def self.name
            'ScopedPostResource'
          end
        end
      end

      let(:serializer) { JPie::Serializer.new(scoped_post_resource_class) }

      it 'returns all posts for admin users' do
        admin_context = { current_user: admin_user }
        scoped_posts = scoped_post_resource_class.scope(admin_context)

        expect(scoped_posts).to include(@admin_post, @user_post, @other_post)
        expect(scoped_posts.count).to eq(3)
      end

      it 'returns only own posts for regular users' do
        user_context = { current_user: regular_user }
        scoped_posts = scoped_post_resource_class.scope(user_context)

        expect(scoped_posts).to include(@user_post)
        expect(scoped_posts).not_to include(@admin_post, @other_post)
        expect(scoped_posts.count).to eq(1)
      end

      it 'returns no posts for unauthenticated users' do
        anonymous_context = { current_user: nil }
        scoped_posts = scoped_post_resource_class.scope(anonymous_context)

        expect(scoped_posts.count).to eq(0)
      end

      it 'serializes scoped results correctly for admin' do
        admin_context = { current_user: admin_user }
        scoped_posts = scoped_post_resource_class.scope(admin_context)
        result = serializer.serialize(scoped_posts, admin_context)

        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(3)
        
        titles = result[:data].map { _1[:attributes]['title'] }
        expect(titles).to contain_exactly('Admin Post', 'User Post', 'Other Post')
      end

      it 'serializes scoped results correctly for regular user' do
        user_context = { current_user: regular_user }
        scoped_posts = scoped_post_resource_class.scope(user_context)
        result = serializer.serialize(scoped_posts, user_context)

        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(1)
        
        expect(result[:data].first[:attributes]['title']).to eq('User Post')
      end
    end

    context 'default scope behavior' do
      it 'returns all records when using default scope' do
        default_posts = PostResource.scope
        expect(default_posts.count).to eq(3)
        expect(default_posts).to include(@admin_post, @user_post, @other_post)
      end

      it 'ignores context in default scope' do
        context_with_user = { current_user: regular_user }
        default_posts = PostResource.scope(context_with_user)
        expect(default_posts.count).to eq(3)
        expect(default_posts).to include(@admin_post, @user_post, @other_post)
      end
    end
  end
end 