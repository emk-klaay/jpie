# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Through Association Support' do
  # Test models - Vehicle2 has many drivers through vehicle_drivers
  before(:all) do
    ActiveRecord::Schema.define do
      create_table :vehicle2s, force: true do |t|
        t.string :make
        t.string :model
        t.integer :year
        t.timestamps
      end

      create_table :driver2s, force: true do |t|
        t.string :name
        t.string :license_number
        t.timestamps
      end

      create_table :vehicle_drivers, force: true do |t|
        t.integer :vehicle2_id
        t.integer :driver2_id
        t.timestamps
      end
    end

    # Define models within the test
    unless defined?(Driver2)
      class Driver2 < ActiveRecord::Base
        has_many :vehicle_drivers, dependent: :destroy
        has_many :vehicle2s, through: :vehicle_drivers
      end
    end

    unless defined?(VehicleDriver)
      class VehicleDriver < ActiveRecord::Base
        belongs_to :vehicle2
        belongs_to :driver2
      end
    end

    unless defined?(Vehicle2)
      class Vehicle2 < ActiveRecord::Base
        has_many :vehicle_drivers, dependent: :destroy
        has_many :driver2s, through: :vehicle_drivers
      end
    end
  end

  after(:all) do
    # Clean up the test tables
    ActiveRecord::Schema.define do
      drop_table :vehicle_drivers if table_exists?(:vehicle_drivers)
      drop_table :driver2s if table_exists?(:driver2s)
      drop_table :vehicle2s if table_exists?(:vehicle2s)
    end
  end

  let!(:vehicle) { Vehicle2.create!(make: 'Toyota', model: 'Camry', year: 2022) }
  let!(:driver1) { Driver2.create!(name: 'John Doe', license_number: 'ABC123') }
  let!(:driver2) { Driver2.create!(name: 'Jane Smith', license_number: 'XYZ789') }

  before do
    # Create the through relationships
    VehicleDriver.create!(vehicle2: vehicle, driver2: driver1)
    VehicleDriver.create!(vehicle2: vehicle, driver2: driver2)
  end

  describe 'Vehicle2Resource with through association' do
    let(:vehicle_resource_class) do
      Class.new(JPie::Resource) do
        model Vehicle2
        type 'vehicle2s'

        attributes :make, :model, :year
        meta_attributes :created_at, :updated_at

        # Test the new through: option
        has_many :driver2s, through: :vehicle_drivers

        def self.name
          'Vehicle2Resource'
        end
      end
    end

    let(:driver_resource_class) do
      Class.new(JPie::Resource) do
        model Driver2
        type 'driver2s'

        attributes :name, :license_number
        meta_attributes :created_at, :updated_at

        def self.name
          'Driver2Resource'
        end
      end
    end

    let(:vehicle_resource) { vehicle_resource_class.new(vehicle) }
    let(:serializer) { JPie::Serializer.new(vehicle_resource_class) }

    before do
      # Register the driver resource class so it can be found
      stub_const('Driver2Resource', driver_resource_class)
    end

    describe 'resource definition' do
      it 'stores the through option in the relationship' do
        relationship_options = vehicle_resource_class._relationships[:driver2s]
        expect(relationship_options[:through]).to eq(:vehicle_drivers)
      end

      it 'defines the relationship method on the resource instance' do
        expect(vehicle_resource).to respond_to(:driver2s)
      end

      it 'returns drivers through the association' do
        drivers = vehicle_resource.driver2s
        expect(drivers.count).to eq(2)
        expect(drivers).to include(driver1, driver2)
      end
    end

    describe 'serialization with includes' do
      it 'includes drivers when requested' do
        result = serializer.serialize(vehicle, {}, includes: ['driver2s'])

        expect(result[:included]).to be_present
        driver_items = result[:included].select { |item| item[:type] == 'driver2s' }
        expect(driver_items.count).to eq(2)

        driver_names = driver_items.map { |d| d[:attributes]['name'] }
        expect(driver_names).to contain_exactly('John Doe', 'Jane Smith')
      end

      it 'does not expose the join table' do
        result = serializer.serialize(vehicle, {}, includes: ['driver2s'])

        # Should not expose vehicle_drivers in the result
        vehicle_driver_items = result[:included].select { |item| item[:type] == 'vehicle_drivers' }
        expect(vehicle_driver_items).to be_empty
      end

      it 'supports nested includes through the association' do
        # Add a profile model for drivers to test deeper nesting
        ActiveRecord::Schema.define do
          create_table :driver2_profiles, force: true do |t|
            t.integer :driver2_id
            t.text :bio
            t.timestamps
          end
        end

        unless defined?(Driver2Profile)
          class Driver2Profile < ActiveRecord::Base
            belongs_to :driver2
          end
        end

        # Update Driver2 model to have a profile
        Driver2.class_eval do
          has_one :driver2_profile, dependent: :destroy
          has_one :profile, class_name: 'Driver2Profile', foreign_key: 'driver2_id'
        end

        profile1 = Driver2Profile.create!(driver2: driver1, bio: 'Experienced driver')
        profile2 = Driver2Profile.create!(driver2: driver2, bio: 'Safe driver')

        # Add profile resource class
        profile_resource_class = Class.new(JPie::Resource) do
          model Driver2Profile
          type 'driver2_profiles'

          attributes :bio
          meta_attributes :created_at, :updated_at

          def self.name
            'Driver2ProfileResource'
          end
        end

        stub_const('Driver2ProfileResource', profile_resource_class)

        # Update driver resource to include profile
        driver_resource_class.class_eval do
          has_one :profile, resource: 'Driver2ProfileResource'
        end

        result = serializer.serialize(vehicle, {}, includes: ['driver2s.profile'])

        expect(result[:included]).to be_present

        driver_items = result[:included].select { |item| item[:type] == 'driver2s' }
        profile_items = result[:included].select { |item| item[:type] == 'driver2_profiles' }

        expect(driver_items.count).to eq(2)
        expect(profile_items.count).to eq(2)

        # Clean up
        ActiveRecord::Schema.define do
          drop_table :driver2_profiles
        end
      end
    end
  end

  describe 'Driver2Resource with reverse through association' do
    let(:driver_resource_class) do
      Class.new(JPie::Resource) do
        model Driver2
        type 'driver2s'

        attributes :name, :license_number
        meta_attributes :created_at, :updated_at

        # Test the reverse through association
        has_many :vehicle2s, through: :vehicle_drivers

        def self.name
          'Driver2Resource'
        end
      end
    end

    let(:vehicle_resource_class) do
      Class.new(JPie::Resource) do
        model Vehicle2
        type 'vehicle2s'

        attributes :make, :model, :year
        meta_attributes :created_at, :updated_at

        def self.name
          'Vehicle2Resource'
        end
      end
    end

    let(:driver_resource) { driver_resource_class.new(driver1) }
    let(:serializer) { JPie::Serializer.new(driver_resource_class) }

    before do
      stub_const('Vehicle2Resource', vehicle_resource_class)
    end

    it 'returns vehicles through the association' do
      vehicles = driver_resource.vehicle2s
      expect(vehicles.count).to eq(1)
      expect(vehicles).to include(vehicle)
    end

    it 'includes vehicles when requested in serialization' do
      result = serializer.serialize(driver1, {}, includes: ['vehicle2s'])

      expect(result[:included]).to be_present
      vehicle_items = result[:included].select { |item| item[:type] == 'vehicle2s' }
      expect(vehicle_items.count).to eq(1)

      expect(vehicle_items.first[:attributes]['make']).to eq('Toyota')
      expect(vehicle_items.first[:attributes]['model']).to eq('Camry')
    end
  end

  describe 'complex through associations' do
    let(:driver_resource_class) do
      Class.new(JPie::Resource) do
        model Driver2
        type 'driver2s'

        attributes :name, :license_number
        meta_attributes :created_at, :updated_at

        def self.name
          'Driver2Resource'
        end
      end
    end

    it 'handles through associations with custom names' do
      custom_vehicle_resource_class = Class.new(JPie::Resource) do
        model Vehicle2
        type 'vehicle2s'

        attributes :make, :model, :year
        meta_attributes :created_at, :updated_at

        # Use a custom relationship name with through
        has_many :operators, through: :vehicle_drivers, attr: :driver2s, resource: 'Driver2Resource'

        def self.name
          'CustomVehicle2Resource'
        end
      end

      stub_const('Driver2Resource', driver_resource_class)
      vehicle_resource = custom_vehicle_resource_class.new(vehicle)

      operators = vehicle_resource.operators
      expect(operators.count).to eq(2)
      expect(operators).to include(driver1, driver2)
    end
  end
end 