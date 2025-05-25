RSpec.shared_examples 'automatic author assignment' do |resource_type, attributes|
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:controller_class) { create_test_controller("#{resource_type.to_s.classify.pluralize}Controller") }
  let(:controller) { controller_class.new }

  before do
    # Store user in instance variable to avoid closure issues
    @test_user = user
    controller.define_singleton_method(:current_user) { @test_user }
  end

  it "creates #{resource_type} with provided attributes" do
    # Set up the request body for create action
    resource_params = {
      data: {
        type: resource_type.to_s.pluralize,
        attributes: attributes
      }
    }

    controller.request.set_body(resource_params.to_json)
    controller.request.set_method('POST')
    controller.request.content_type = 'application/vnd.api+json'

    controller.create

    expect(controller.last_render[:status]).to eq(:created)

    created_resource = resource_type.to_s.classify.constantize.last
    
    # Verify the resource was created with the provided attributes
    attributes.each do |key, value|
      expect(created_resource.send(key)).to eq(value)
    end
    
    # Verify the response contains the created resource
    response_data = controller.last_render[:json]
    expect(response_data[:data][:type]).to eq(resource_type.to_s.pluralize)
    expect(response_data[:data][:id]).to eq(created_resource.id.to_s)
  end
end

RSpec.shared_examples 'standard CRUD operations' do |resource_type, factory_attributes|
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:resource_class) { resource_type.to_s.classify.constantize }
  let(:controller_class) { create_test_controller("#{resource_type.to_s.classify.pluralize}Controller") }
  let(:controller) { controller_class.new }
  
  # Use the correct association name based on the model
  let(:resource) do
    if resource_type == :post
      resource_class.create!(factory_attributes.merge(user: user))
    else
      resource_class.create!(factory_attributes.merge(author: user))
    end
  end

  before do
    # Store user in instance variable to avoid closure issues
    @test_user = user
    controller.define_singleton_method(:current_user) { @test_user }
  end

  describe 'GET (Read) operations' do
    it 'retrieves individual resource' do
      controller.params = { id: resource.id.to_s }
      controller.show

      expect(controller.last_render[:status]).to eq(:ok)
      expect(controller.last_render[:json][:data][:id]).to eq(resource.id.to_s)
      expect(controller.last_render[:json][:data][:type]).to eq(resource_type.to_s.pluralize)
    end

    it 'retrieves collection of resources' do
      resource # Ensure resource exists

      controller.index

      expect(controller.last_render[:status]).to eq(:ok)
      expect(controller.last_render[:json][:data]).to be_an(Array)
      expect(controller.last_render[:json][:data].size).to be >= 1
    end
  end

  describe 'PATCH (Update) operations' do
    it 'updates resource without affecting author' do
      update_attributes = factory_attributes.keys.first
      new_value = "Updated #{factory_attributes.values.first}"
      
      update_params = {
        data: {
          id: resource.id.to_s,
          type: resource_type.to_s.pluralize,
          attributes: { update_attributes => new_value }
        }
      }

      controller.params = { id: resource.id.to_s }
      controller.request.set_body(update_params.to_json)
      controller.request.set_method('PATCH')
      controller.request.content_type = 'application/vnd.api+json'

      controller.update

      expect(controller.last_render[:status]).to eq(:ok)

      resource.reload
      expect(resource.send(update_attributes)).to eq(new_value)
      
      # Use the correct association name based on the model
      if resource_type == :post
        expect(resource.user).to eq(user)
      else
        expect(resource.author).to eq(user)
      end
    end
  end

  describe 'DELETE operations' do
    it 'deletes resource successfully' do
      resource_id = resource.id
      controller.params = { id: resource_id.to_s }

      expect do
        controller.destroy
      end.to change(resource_class, :count).by(-1)

      expect(controller.last_head).to eq(:no_content)
    end
  end
end

RSpec.shared_examples 'JSON:API content type validation' do
  it 'passes with correct content type' do
    controller.request.content_type = 'application/vnd.api+json'
    controller.request.set_method('POST')

    expect { controller.send(:validate_content_type) }.not_to raise_error
  end

  it 'raises error with incorrect content type' do
    controller.request.content_type = 'application/json'
    controller.request.set_method('POST')

    expect { controller.send(:validate_content_type) }.to raise_error(
      JPie::Errors::InvalidJsonApiRequestError,
      %r{Content-Type must be application/vnd\.api\+json}
    )
  end

  it 'skips validation for GET requests' do
    controller.request.content_type = 'application/json'
    controller.request.set_method('GET')

    expect { controller.send(:validate_content_type) }.not_to raise_error
  end
end

RSpec.shared_examples 'JSON:API structure validation' do
  it 'passes with valid JSON:API structure' do
    valid_json = {
      data: {
        type: 'users',
        attributes: { name: 'John' }
      }
    }.to_json

    controller.request.set_body(valid_json)
    controller.request.set_method('POST')

    expect { controller.send(:validate_json_api_structure) }.not_to raise_error
  end

  it 'raises error with missing data member' do
    invalid_json = { type: 'users' }.to_json
    controller.request.set_body(invalid_json)
    controller.request.set_method('POST')

    expect { controller.send(:validate_json_api_structure) }.to raise_error(
      JPie::Errors::InvalidJsonApiRequestError,
      /must have a top-level "data" member/
    )
  end

  it 'raises error with invalid JSON' do
    controller.request.set_body('invalid json')
    controller.request.set_method('POST')

    expect { controller.send(:validate_json_api_structure) }.to raise_error(
      JPie::Errors::InvalidJsonApiRequestError,
      /Invalid JSON/
    )
  end

  it 'raises error with missing type in resource object' do
    invalid_json = {
      data: {
        attributes: { name: 'John' }
      }
    }.to_json

    controller.request.set_body(invalid_json)
    controller.request.set_method('POST')

    expect { controller.send(:validate_json_api_structure) }.to raise_error(
      JPie::Errors::InvalidJsonApiRequestError,
      /must have a "type" member/
    )
  end
end 