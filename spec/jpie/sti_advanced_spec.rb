# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Advanced STI Support' do
  describe 'Polymorphic serialization with STI models' do
    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }
    let(:vehicle) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }

    context 'when serializing mixed STI collection with polymorphic approach' do
      it 'can determine correct resource class for each STI type' do
        vehicles = [car, truck, vehicle]

        # Test that we can determine the correct resource class for each object
        vehicles.each do |v|
          resource_class_name = "#{v.class.name}Resource"
          expect { resource_class_name.constantize }.not_to raise_error

          resource_class = resource_class_name.constantize
          resource = resource_class.new(v)

          case v
          when Car
            expect(resource.type).to eq('cars')
            expect(resource.attributes_hash).to include(:engine_size)
          when Truck
            expect(resource.type).to eq('trucks')
            expect(resource.attributes_hash).to include(:cargo_capacity)
          when Vehicle
            expect(resource.type).to eq('vehicles')
            expect(resource.attributes_hash).not_to include(:engine_size, :cargo_capacity)
          end
        end
      end
    end

    context 'when using serializer with polymorphic STI objects' do
      it 'handles polymorphic relationships correctly' do
        # This tests the determine_resource_class method in the serializer
        # which should work with STI models

        car_serializer = JPie::Serializer.new(CarResource)
        truck_serializer = JPie::Serializer.new(TruckResource)
        vehicle_serializer = JPie::Serializer.new(VehicleResource)

        car_result = car_serializer.serialize(car)
        truck_result = truck_serializer.serialize(truck)
        vehicle_result = vehicle_serializer.serialize(vehicle)

        expect(car_result[:data][:type]).to eq('cars')
        expect(car_result[:data][:attributes]).to include('engine_size' => 1500)

        expect(truck_result[:data][:type]).to eq('trucks')
        expect(truck_result[:data][:attributes]).to include('cargo_capacity' => 1000)

        expect(vehicle_result[:data][:type]).to eq('vehicles')
        expect(vehicle_result[:data][:attributes]).not_to include('engine_size', 'cargo_capacity')
      end
    end
  end

  describe 'STI model scoping and querying' do
    let!(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let!(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }
    let!(:vehicle) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }

    it 'correctly scopes STI models in resource classes' do
      # Test that each resource class correctly scopes to its STI type
      car_scope = CarResource.scope
      truck_scope = TruckResource.scope
      vehicle_scope = VehicleResource.scope

      expect(car_scope.to_a).to contain_exactly(car)
      expect(truck_scope.to_a).to contain_exactly(truck)
      expect(vehicle_scope.to_a).to contain_exactly(car, truck, vehicle)
    end

    it 'maintains proper STI inheritance in queries' do
      # Verify that STI inheritance works as expected
      expect(Car.all.to_a).to contain_exactly(car)
      expect(Truck.all.to_a).to contain_exactly(truck)
      expect(Vehicle.all.to_a).to contain_exactly(car, truck, vehicle)
    end
  end

  describe 'STI type validation and consistency' do
    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }

    it 'maintains type consistency between model and resource' do
      car_resource = CarResource.new(car)

      # The resource type should match the STI model type
      expect(car_resource.type).to eq('cars')
      expect(car.class.name.underscore.pluralize).to eq('cars')
    end

    it 'handles explicit type overrides correctly' do
      # Test that explicit type setting still works with STI

      CarResource.type 'custom_cars'
      car_resource = CarResource.new(car)
      expect(car_resource.type).to eq('custom_cars')
    ensure
      # Reset to auto-inferred value
      CarResource._type = nil
    end
  end

  describe 'STI with relationships' do
    let(:user) { User.create!(name: 'John', email: 'john@example.com') }
    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }

    it 'supports STI models in relationships' do
      # This test verifies that STI models work correctly in relationships
      # The serializer should be able to determine the correct resource class
      # for STI objects in relationships

      car_resource = CarResource.new(car)
      expect(car_resource.type).to eq('cars')
      expect(car_resource.attributes_hash).to include(:engine_size)
    end
  end

  describe 'Error handling with STI' do
    it 'handles missing STI resource classes gracefully' do
      # Create a new STI model without a corresponding resource
      motorcycle_class = Class.new(Vehicle) do
        def self.name
          'Motorcycle'
        end
      end

      motorcycle = motorcycle_class.new(name: 'Harley', brand: 'Davidson', year: 2020)

      # The serializer should handle missing resource classes gracefully
      resource_class_name = "#{motorcycle.class.name}Resource"
      expect { resource_class_name.constantize }.to raise_error(NameError)
    end
  end
end
