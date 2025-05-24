# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Meta Method Support' do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }

  describe 'Basic meta method functionality' do
    context 'when meta method is defined' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
          meta_attributes :created_at, :updated_at

          def meta
            { custom_field: 'custom_value' }
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'includes custom meta alongside meta attributes' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to include(
          created_at: user.created_at,
          updated_at: user.updated_at,
          custom_field: 'custom_value'
        )
      end

      it 'works with serialization' do
        serializer = JPie::Serializer.new(resource_class)
        result = serializer.serialize(user)

        meta_data = result[:data][:meta]
        expect(meta_data).to include(
          'created_at' => user.created_at.iso8601,
          'updated_at' => user.updated_at.iso8601,
          'custom_field' => 'custom_value'
        )
      end
    end

    context 'when meta method calls super' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
          meta_attributes :created_at, :updated_at

          def meta
            super.merge(additional_field: 'additional_value')
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'merges with existing meta attributes' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to include(
          created_at: user.created_at,
          updated_at: user.updated_at,
          additional_field: 'additional_value'
        )
      end

      it 'allows overriding meta attribute values' do
        resource_class_with_override = Class.new(JPie::Resource) do
          model User
          attributes :name, :email
          meta_attributes :created_at, :updated_at

          def meta
            super.merge(created_at: 'overridden_value')
          end
        end

        resource = resource_class_with_override.new(user)
        meta_hash = resource.meta_hash

        expect(meta_hash[:created_at]).to eq('overridden_value')
        expect(meta_hash[:updated_at]).to eq(user.updated_at)
      end
    end

    context 'when only meta method is defined (no meta_attributes)' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email

          def meta
            { standalone_field: 'standalone_value' }
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'returns only the custom meta' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to eq(
          standalone_field: 'standalone_value'
        )
      end
    end

    context 'when only meta_attributes are defined (no meta method)' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
          meta_attributes :created_at, :updated_at
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'returns only the meta attributes (backward compatibility)' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to eq(
          created_at: user.created_at,
          updated_at: user.updated_at
        )
      end
    end

    context 'when neither meta method nor meta_attributes are defined' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'returns an empty hash' do
        meta_hash = resource.meta_hash
        expect(meta_hash).to eq({})
      end
    end
  end

  describe 'Advanced meta method scenarios' do
    context 'with context usage in meta method' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
          meta_attributes :created_at

          def meta
            super.merge(
              user_role: context[:user_role] || 'guest',
              request_time: context[:request_time] || Time.current
            )
          end
        end
      end

      it 'has access to context in meta method' do
        context = { user_role: 'admin', request_time: Time.parse('2024-01-01T12:00:00Z') }
        resource = resource_class.new(user, context)

        meta_hash = resource.meta_hash
        expect(meta_hash).to include(
          created_at: user.created_at,
          user_role: 'admin',
          request_time: Time.parse('2024-01-01T12:00:00Z')
        )
      end
    end

    context 'with object access in meta method' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email

          def meta
            {
              user_id: object.id,
              email_domain: object.email.split('@').last,
              is_admin: object.email.include?('admin')
            }
          end
        end
      end

      let(:admin_user) { User.create!(name: 'Admin User', email: 'admin@example.com') }
      let(:resource) { resource_class.new(admin_user) }

      it 'has access to object in meta method' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to include(
          user_id: admin_user.id,
          email_domain: 'example.com',
          is_admin: true
        )
      end
    end

    context 'with inheritance' do
      let(:base_resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name
          meta_attributes :created_at

          def meta
            super.merge(base_field: 'base_value')
          end
        end
      end

      let(:derived_resource_class) do
        Class.new(base_resource_class) do
          attributes :email
          meta_attributes :updated_at

          def meta
            super.merge(derived_field: 'derived_value')
          end
        end
      end

      let(:resource) { derived_resource_class.new(user) }

      it 'properly inherits and chains meta methods' do
        meta_hash = resource.meta_hash

        expect(meta_hash).to include(
          created_at: user.created_at,
          updated_at: user.updated_at,
          base_field: 'base_value',
          derived_field: 'derived_value'
        )
      end
    end
  end

  describe 'Error handling' do
    context 'when meta method returns non-hash' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email

          def meta
            'not a hash'
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'raises a helpful error' do
        expect { resource.meta_hash }.to raise_error(
          JPie::Errors::ResourceError,
          /meta method must return a Hash/
        )
      end
    end

    context 'when meta method raises an error' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email

          def meta
            raise StandardError, 'Something went wrong'
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'propagates the error with context' do
        expect { resource.meta_hash }.to raise_error(StandardError, 'Something went wrong')
      end
    end
  end

  describe 'Performance considerations' do
    let(:resource_class) do
      Class.new(JPie::Resource) do
        model User
        attributes :name, :email
        meta_attributes :created_at, :updated_at

        def meta
          # Simulate an expensive operation
          super.merge(expensive_calculation: calculate_something)
        end

        private

        def calculate_something
          # Simulate computation
          @calculate_something ||= (1..100).sum
        end
      end
    end

    let(:resource) { resource_class.new(user) }

    it 'does not cache meta_hash results (allows for dynamic values)' do
      first_call = resource.meta_hash
      second_call = resource.meta_hash

      # Both calls should work and return the same structure
      expect(first_call).to eq(second_call)
      expect(first_call[:expensive_calculation]).to eq(5050)
    end
  end
end
