# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie STI Support' do
  let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
  let(:vehicle) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }

  describe 'STI resource type inference' do
    it 'infers correct types for STI models' do
      car_resource = CarResource.new(car)
      vehicle_resource = VehicleResource.new(vehicle)

      expect(car_resource.type).to eq('cars')
      expect(vehicle_resource.type).to eq('vehicles')
    end

    it 'allows explicit type overrides' do
      CarResource.type 'custom_cars'
      car_resource = CarResource.new(car)
      expect(car_resource.type).to eq('custom_cars')
    ensure
      CarResource._type = nil # Reset
    end
  end

  describe 'STI resource attributes' do
    it 'includes STI-specific attributes correctly' do
      car_resource = CarResource.new(car)
      vehicle_resource = VehicleResource.new(vehicle)

      # Car includes base + specific attributes
      expect(car_resource.attributes_hash).to include(
        name: 'Civic',
        brand: 'Honda',
        year: 2020,
        engine_size: 1500
      )

      # Vehicle includes only base attributes
      expect(vehicle_resource.attributes_hash).to include(
        name: 'Generic',
        brand: 'Unknown',
        year: 2019
      )
      expect(vehicle_resource.attributes_hash).not_to have_key(:engine_size)
    end

    it 'maintains separate attribute inheritance' do
      expect(CarResource._attributes).to include(:name, :brand, :year, :engine_size)
      expect(VehicleResource._attributes).to include(:name, :brand, :year)
      expect(VehicleResource._attributes).not_to include(:engine_size)
    end
  end

  describe 'STI serialization' do
    it 'serializes STI models with correct types and attributes' do
      car_serializer = JPie::Serializer.new(CarResource)
      vehicle_serializer = JPie::Serializer.new(VehicleResource)

      car_result = car_serializer.serialize(car)
      vehicle_result = vehicle_serializer.serialize(vehicle)

      expect(car_result[:data]).to include(
        id: car.id.to_s,
        type: 'cars',
        attributes: {
          'name' => 'Civic',
          'brand' => 'Honda',
          'year' => 2020,
          'engine_size' => 1500
        }
      )

      expect(vehicle_result[:data]).to include(
        id: vehicle.id.to_s,
        type: 'vehicles',
        attributes: {
          'name' => 'Generic',
          'brand' => 'Unknown',
          'year' => 2019
        }
      )
    end
  end

  describe 'STI resource class determination' do
    let(:serializer) { JPie::Serializer.new(VehicleResource) }

    it 'determines correct resource class for STI objects' do
      # Test the serializer's determine_resource_class method
      car_resource_class = serializer.send(:determine_resource_class, car, {})
      vehicle_resource_class = serializer.send(:determine_resource_class, vehicle, {})

      expect(car_resource_class).to eq(CarResource)
      expect(vehicle_resource_class).to eq(VehicleResource)
    end

    it 'respects explicit resource class over STI inference' do
      relationship_options = { resource: 'VehicleResource' }
      resource_class = serializer.send(:determine_resource_class, car, relationship_options)
      expect(resource_class).to eq(VehicleResource)
    end

    it 'handles missing STI resource classes gracefully' do
      motorcycle = double('motorcycle')
      allow(motorcycle).to receive(:class).and_return(double('motorcycle_class', name: 'Motorcycle'))

      resource_class = serializer.send(:determine_resource_class, motorcycle, {})
      expect(resource_class).to be_nil
    end
  end

  describe 'STI model scoping' do
    let!(:car_instance) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let!(:vehicle_instance) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }

    it 'correctly scopes STI models in resource classes' do
      car_scope = CarResource.scope
      vehicle_scope = VehicleResource.scope

      expect(car_scope.to_a).to contain_exactly(car_instance)
      expect(vehicle_scope.to_a).to contain_exactly(car_instance, vehicle_instance)
    end

    it 'maintains proper STI inheritance in ActiveRecord queries' do
      expect(Car.all.to_a).to contain_exactly(car_instance)
      expect(Vehicle.all.to_a).to contain_exactly(car_instance, vehicle_instance)
    end
  end

  describe 'STI polymorphic scenarios' do
    it 'handles mixed STI collections correctly' do
      vehicles = [car, vehicle]

      vehicles.each do |v|
        resource_class_name = "#{v.class.name}Resource"
        expect { resource_class_name.constantize }.not_to raise_error

        resource_class = resource_class_name.constantize
        resource = resource_class.new(v)

        case v
        when Car
          expect(resource.type).to eq('cars')
          expect(resource.attributes_hash).to include(:engine_size)
        when Vehicle
          expect(resource.type).to eq('vehicles')
          expect(resource.attributes_hash).not_to include(:engine_size)
        end
      end
    end
  end

  describe 'STI error handling' do
    it 'handles missing STI resource classes gracefully' do
      motorcycle_class = Class.new(Vehicle) do
        def self.name
          'Motorcycle'
        end
      end

      motorcycle = motorcycle_class.new(name: 'Harley', brand: 'Davidson', year: 2020)
      resource_class_name = "#{motorcycle.class.name}Resource"

      expect { resource_class_name.constantize }.to raise_error(NameError)
    end
  end
end
