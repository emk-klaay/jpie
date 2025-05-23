# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'STI Polymorphic Serialization' do
  describe 'Serializer determine_resource_class with STI models' do
    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }
    let(:vehicle) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }

    let(:serializer) { JPie::Serializer.new(VehicleResource) }

    it 'determines correct resource class for STI Car model' do
      # Test the private determine_resource_class method
      relationship_options = {}

      # Access the private method for testing
      resource_class = serializer.send(:determine_resource_class, car, relationship_options)

      expect(resource_class).to eq(CarResource)
    end

    it 'determines correct resource class for STI Truck model' do
      relationship_options = {}

      resource_class = serializer.send(:determine_resource_class, truck, relationship_options)

      expect(resource_class).to eq(TruckResource)
    end

    it 'determines correct resource class for base Vehicle model' do
      relationship_options = {}

      resource_class = serializer.send(:determine_resource_class, vehicle, relationship_options)

      expect(resource_class).to eq(VehicleResource)
    end

    it 'respects explicit resource class over STI inference' do
      # When a relationship explicitly specifies a resource class, it should use that
      relationship_options = { resource: 'VehicleResource' }

      resource_class = serializer.send(:determine_resource_class, car, relationship_options)

      expect(resource_class).to eq(VehicleResource)
    end

    it 'handles missing STI resource classes gracefully' do
      # Create a mock STI object without a corresponding resource
      motorcycle = double('motorcycle')
      allow(motorcycle).to receive(:class).and_return(double('motorcycle_class', name: 'Motorcycle'))

      relationship_options = {}

      resource_class = serializer.send(:determine_resource_class, motorcycle, relationship_options)

      expect(resource_class).to be_nil
    end
  end

  describe 'Full serialization with STI polymorphic includes' do
    # This would test a more complex scenario where STI models are included
    # in polymorphic relationships, but requires setting up associations
    # For now, we'll test the core functionality

    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }

    it 'serializes STI models with correct types and attributes' do
      car_serializer = JPie::Serializer.new(CarResource)
      truck_serializer = JPie::Serializer.new(TruckResource)

      car_result = car_serializer.serialize(car)
      truck_result = truck_serializer.serialize(truck)

      # Verify Car serialization
      expect(car_result[:data]).to include(
        id: car.id.to_s,
        type: 'cars',
        attributes: hash_including(
          'name' => 'Civic',
          'brand' => 'Honda',
          'year' => 2020,
          'engine_size' => 1500
        )
      )

      # Verify Truck serialization
      expect(truck_result[:data]).to include(
        id: truck.id.to_s,
        type: 'trucks',
        attributes: hash_including(
          'name' => 'F-150',
          'brand' => 'Ford',
          'year' => 2021,
          'cargo_capacity' => 1000
        )
      )
    end

    it 'serializes collection of mixed STI types' do
      [car, truck]

      # In a real scenario, you might have a polymorphic serializer that can handle mixed types
      # For now, we test individual serialization
      car_serializer = JPie::Serializer.new(CarResource)
      truck_serializer = JPie::Serializer.new(TruckResource)

      car_result = car_serializer.serialize(car)
      truck_result = truck_serializer.serialize(truck)

      expect(car_result[:data][:type]).to eq('cars')
      expect(truck_result[:data][:type]).to eq('trucks')

      # Each should have their specific attributes
      expect(car_result[:data][:attributes]).to include('engine_size' => 1500)
      expect(truck_result[:data][:attributes]).to include('cargo_capacity' => 1000)
    end
  end
end
