# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PostResource do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let(:post_instance) do
    Post.create!(
      title: 'Test Post',
      content: 'This is a test post content',
      user: user
    )
  end
  let(:resource_instance) { described_class.new(post_instance) }

  describe '.model' do
    it 'returns the Post model class' do
      expect(described_class.model).to eq(Post)
    end
  end

  describe '.type' do
    it 'returns the correct pluralized type' do
      expect(described_class.type).to eq('posts')
    end
  end

  describe '.attribute' do
    it 'defines the correct attributes' do
      expect(described_class._attributes).to contain_exactly(:title, :content, :user_id, :created_at, :updated_at)
    end
  end

  describe '#attributes_hash' do
    it 'returns a hash of all attributes' do
      attributes = resource_instance.attributes_hash

      expect(attributes).to include(
        title: 'Test Post',
        content: 'This is a test post content',
        user_id: user.id
      )
      expect(attributes).to have_key(:created_at)
      expect(attributes).to have_key(:updated_at)
    end
  end

  describe 'attribute access' do
    it 'returns the correct attribute values' do
      expect(resource_instance.title).to eq('Test Post')
      expect(resource_instance.content).to eq('This is a test post content')
      expect(resource_instance.user_id).to eq(user.id)
    end
  end
end
