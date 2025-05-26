# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::RSpec do
  before do
    described_class.configure!
  end

  let(:resource) do
    JPie::Resource.new(
      type: 'posts',
      id: '1',
      attributes: { 'title' => 'Test Post', 'content' => 'Test Content' },
      relationships: { 'author' => { 'data' => { 'type' => 'users', 'id' => '1' } } }
    )
  end

  let(:unpersisted_resource) do
    JPie::Resource.new(
      type: 'posts',
      attributes: { 'title' => 'Draft Post' }
    )
  end

  describe 'matchers' do
    describe ':have_attribute' do
      it 'matches when attribute exists' do
        expect(resource).to have_attribute(:title)
        expect(resource).to have_attribute(:content)
      end

      it 'does not match when attribute does not exist' do
        expect(resource).not_to have_attribute(:non_existent)
      end

      it 'provides a helpful failure message' do
        matcher = have_attribute(:non_existent)
        matcher.matches?(resource)
        expect(matcher.failure_message).to include('expected')
        expect(matcher.failure_message).to include('to have attribute')
      end
    end

    describe ':have_relationship' do
      it 'matches when relationship exists' do
        expect(resource).to have_relationship(:author)
      end

      it 'does not match when relationship does not exist' do
        expect(resource).not_to have_relationship(:non_existent)
      end

      it 'provides a helpful failure message' do
        matcher = have_relationship(:non_existent)
        matcher.matches?(resource)
        expect(matcher.failure_message).to include('expected')
        expect(matcher.failure_message).to include('to have relationship')
      end
    end
  end

  describe 'helpers' do
    describe '#build_jpie_resource' do
      let(:built_resource) do
        build_jpie_resource(
          'posts',
          { title: 'Test' },
          { author: { data: { type: 'users', id: '1' } } }
        )
      end

      it 'creates an unpersisted resource' do
        expect(built_resource).to be_a(JPie::Resource)
        expect(built_resource.id).to be_nil
      end

      it 'sets the correct type' do
        expect(built_resource.type).to eq('posts')
      end

      it 'sets the attributes' do
        expect(built_resource).to have_attribute(:title)
        expect(built_resource.title).to eq('Test')
      end

      it 'sets the relationships' do
        expect(built_resource).to have_relationship(:author)
      end
    end

    describe '#create_jpie_resource' do
      let(:created_resource) { create_jpie_resource('posts', { title: 'Test' }) }
      let(:resource_instance) { instance_double(JPie::Resource, save: true) }

      before do
        allow(JPie::Resource).to receive(:new).and_return(resource_instance)
      end

      it 'creates and attempts to save the resource' do
        expect(created_resource).to eq(resource_instance)
        expect(resource_instance).to have_received(:save)
      end
    end

    describe '#cleanup_jpie_resources' do
      let(:resources) { [resource, unpersisted_resource] }

      before do
        allow(resource).to receive(:destroy)
        allow(resource).to receive(:persisted?).and_return(true)
        allow(unpersisted_resource).to receive(:persisted?).and_return(false)
      end

      it 'attempts to destroy persisted resources' do
        expect(resource).to receive(:destroy)
        cleanup_jpie_resources(resources)
      end

      it 'handles errors gracefully' do
        allow(resource).to receive(:destroy).and_raise(StandardError, 'Test error')
        expect { cleanup_jpie_resources(resources) }.not_to raise_error
      end

      it 'skips unpersisted resources' do
        expect(unpersisted_resource).not_to receive(:destroy)
        cleanup_jpie_resources(resources)
      end
    end
  end
end
