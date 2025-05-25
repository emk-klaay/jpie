# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Resource Method Override Support' do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com', created_at: Time.current) }

  describe 'Custom attribute methods' do
    context 'when custom method is defined before attribute declaration' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Define custom method before declaring attribute
          def full_name
            "#{object.name} (#{object.email.split('@').first})"
          end

          attribute :full_name
          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'uses the custom method instead of model attribute' do
        expect(resource.full_name).to eq('John Doe (john)')
      end

      it 'includes custom attribute in attributes_hash' do
        attributes = resource.attributes_hash
        expect(attributes[:full_name]).to eq('John Doe (john)')
      end

      it 'lists the custom attribute in _attributes' do
        expect(resource_class._attributes).to include(:full_name)
      end
    end

    context 'when custom method is defined after attribute declaration' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Declare attribute first
          attribute :full_name
          attributes :name, :email

          # Define custom method after declaring attribute
          def full_name
            "#{object.name} (Custom)"
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'uses the custom method that overrides the default' do
        expect(resource.full_name).to eq('John Doe (Custom)')
      end
    end

    context 'with access to object and context' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          def display_name
            if context[:admin]
              "#{object.name} [ADMIN VIEW] - #{object.email}"
            else
              object.name
            end
          end

          attribute :display_name
          attributes :name, :email
        end
      end

      it 'has access to object in custom method' do
        resource = resource_class.new(user)
        expect(resource.display_name).to eq('John Doe')
      end

      it 'has access to context in custom method' do
        resource = resource_class.new(user, { admin: true })
        expect(resource.display_name).to eq('John Doe [ADMIN VIEW] - john@example.com')
      end
    end

    context 'with private methods' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          attribute :formatted_info
          attributes :name, :email

          private

          def formatted_info
            "#{format_name} - #{format_email}"
          end

          def format_name
            object.name.upcase
          end

          def format_email
            "[#{object.email}]"
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'allows private method implementations' do
        # Private methods should work when accessed through attributes_hash
        attributes = resource.attributes_hash
        expect(attributes[:formatted_info]).to eq('JOHN DOE - [john@example.com]')

        # But should not be callable directly (this is expected Ruby behavior)
        expect { resource.formatted_info }.to raise_error(NoMethodError, /private method/)
      end
    end
  end

  describe 'Custom meta_attribute methods' do
    context 'when custom method is defined before meta_attribute declaration' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Define custom method before declaring meta_attribute
          def user_stats
            {
              name_length: object.name.length,
              email_domain: object.email.split('@').last,
              created_today: object.created_at.to_date == Time.current.utc.to_date
            }
          end

          meta_attribute :user_stats
          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'uses the custom method for meta attribute' do
        stats = resource.user_stats
        expect(stats[:name_length]).to eq(8) # "John Doe"
        expect(stats[:email_domain]).to eq('example.com')
        expect(stats[:created_today]).to be true
      end

      it 'includes custom meta attribute in meta_hash' do
        meta = resource.meta_hash
        expect(meta[:user_stats]).to be_a(Hash)
        expect(meta[:user_stats][:name_length]).to eq(8)
      end

      it 'lists the custom meta attribute in _meta_attributes' do
        expect(resource_class._meta_attributes).to include(:user_stats)
      end
    end

    context 'when custom method is defined after meta_attribute declaration' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Declare meta_attribute first
          meta_attribute :computed_value
          attributes :name, :email

          # Define custom method after declaring meta_attribute
          def computed_value
            "Computed: #{object.name.length}"
          end
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'uses the custom method that overrides the default' do
        expect(resource.computed_value).to eq('Computed: 8')
      end
    end
  end

  describe 'Custom relationship methods' do
    let(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }

    context 'when custom method is defined before relationship declaration' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model Post

          # Define custom relationship method
          def author
            # Return a custom wrapper instead of just the user
            {
              user: object.user,
              role: 'Author',
              post_count: object.user.posts.count
            }
          end

          relationship :author
          attributes :title, :content
        end
      end

      let(:resource) { resource_class.new(post) }

      it 'uses the custom method for relationship' do
        author_data = resource.author
        expect(author_data[:user]).to eq(user)
        expect(author_data[:role]).to eq('Author')
        expect(author_data[:post_count]).to eq(1)
      end

      it 'lists the custom relationship in _relationships' do
        expect(resource_class._relationships).to have_key(:author)
      end
    end
  end

  describe 'Backward compatibility' do
    context 'with existing block syntax' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          attribute :display_name do
            "#{object.name} (Block)"
          end

          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'still works with block syntax' do
        expect(resource.display_name).to eq('John Doe (Block)')
      end
    end

    context 'with existing options[:block] syntax' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          attribute :display_name, block: proc { "#{object.name} (Options Block)" }
          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'still works with options[:block] syntax' do
        expect(resource.display_name).to eq('John Doe (Options Block)')
      end
    end

    context 'with regular model attributes' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User
          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'still works with regular model attribute lookup' do
        expect(resource.name).to eq('John Doe')
        expect(resource.email).to eq('john@example.com')
      end
    end
  end

  describe 'Method precedence' do
    context 'when both custom method and block are provided' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Custom method defined first
          def full_name
            "#{object.name} (Method)"
          end

          # Block provided - should override the custom method
          attribute :full_name do
            "#{object.name} (Block)"
          end

          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'prioritizes block over custom method' do
        expect(resource.full_name).to eq('John Doe (Block)')
      end
    end

    context 'when both custom method and options[:block] are provided' do
      let(:resource_class) do
        Class.new(JPie::Resource) do
          model User

          # Custom method defined first
          def full_name
            "#{object.name} (Method)"
          end

          # Options block provided - should override the custom method
          attribute :full_name, block: proc { "#{object.name} (Options Block)" }

          attributes :name, :email
        end
      end

      let(:resource) { resource_class.new(user) }

      it 'prioritizes options[:block] over custom method' do
        expect(resource.full_name).to eq('John Doe (Options Block)')
      end
    end
  end

  describe 'Inheritance behavior' do
    context 'with custom methods in parent and child classes' do
      let(:base_resource_class) do
        Class.new(JPie::Resource) do
          model User

          def full_name
            "#{object.name} (Base)"
          end

          attribute :full_name
          attributes :name, :email
        end
      end

      let(:derived_resource_class) do
        Class.new(base_resource_class) do
          # Override the parent's custom method
          def full_name
            "#{object.name} (Derived)"
          end
        end
      end

      it 'allows child classes to override parent custom methods' do
        base_resource = base_resource_class.new(user)
        derived_resource = derived_resource_class.new(user)

        expect(base_resource.full_name).to eq('John Doe (Base)')
        expect(derived_resource.full_name).to eq('John Doe (Derived)')
      end

      it 'inherits attributes list correctly' do
        expect(derived_resource_class._attributes).to include(:full_name, :name, :email)
      end
    end
  end
end
