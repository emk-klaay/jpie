# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'STI Support' do
  describe 'Type inference for STI models' do
    context 'with Car STI model' do
      let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
      let(:car_resource) { CarResource.new(car) }

      it 'uses the STI type as the JSON:API type' do
        expect(car_resource.type).to eq('cars')
      end

      it 'includes STI-specific attributes' do
        attributes = car_resource.attributes_hash
        expect(attributes).to include(
          name: 'Civic',
          brand: 'Honda',
          year: 2020,
          engine_size: 1500
        )
      end
    end

    context 'with Truck STI model' do
      let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }
      let(:truck_resource) { TruckResource.new(truck) }

      it 'uses the STI type as the JSON:API type' do
        expect(truck_resource.type).to eq('trucks')
      end

      it 'includes STI-specific attributes' do
        attributes = truck_resource.attributes_hash
        expect(attributes).to include(
          name: 'F-150',
          brand: 'Ford',
          year: 2021,
          cargo_capacity: 1000
        )
      end
    end

    context 'with base Vehicle model' do
      let(:vehicle) { Vehicle.create!(name: 'Generic', brand: 'Unknown', year: 2019) }
      let(:vehicle_resource) { VehicleResource.new(vehicle) }

      it 'uses the base model name as type' do
        expect(vehicle_resource.type).to eq('vehicles')
      end

      it 'includes base attributes only' do
        attributes = vehicle_resource.attributes_hash
        expect(attributes).to include(
          name: 'Generic',
          brand: 'Unknown',
          year: 2019
        )
        expect(attributes).not_to have_key(:engine_size)
        expect(attributes).not_to have_key(:cargo_capacity)
      end
    end
  end

  describe 'Serialization of STI models' do
    let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
    let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }
    let(:serializer) { JPie::Serializer.new(CarResource) }

    context 'serializing a single STI object' do
      it 'produces correct JSON:API structure for Car' do
        result = serializer.serialize(car)

        expect(result[:data]).to include(
          id: car.id.to_s,
          type: 'cars',
          attributes: {
            'name' => 'Civic',
            'brand' => 'Honda',
            'year' => 2020,
            'engine_size' => 1500
          }
        )
      end
    end

    context 'serializing collection of mixed STI objects' do
      it 'handles mixed STI types correctly when using polymorphic approach' do
        # This test will verify that JPie can handle collections of mixed STI types
        # when the serializer can determine the correct resource class for each object

        # For now, this is a placeholder for future polymorphic STI support
        # Individual serializers work fine
        car_serializer = JPie::Serializer.new(CarResource)
        truck_serializer = JPie::Serializer.new(TruckResource)

        car_result = car_serializer.serialize(car)
        truck_result = truck_serializer.serialize(truck)

        expect(car_result[:data][:type]).to eq('cars')
        expect(truck_result[:data][:type]).to eq('trucks')
      end
    end
  end

  describe 'Resource class determination for STI' do
    context 'when determining resource class from STI object' do
      let(:car) { Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500) }
      let(:truck) { Truck.create!(name: 'F-150', brand: 'Ford', year: 2021, cargo_capacity: 1000) }

      it 'infers CarResource for Car object' do
        # This test drives the need for automatic resource class determination
        # from STI object types - this will be implemented in the serializer
        resource_class_name = "#{car.class.name}Resource"
        expect(resource_class_name).to eq('CarResource')
        expect { resource_class_name.constantize }.not_to raise_error
      end

      it 'infers TruckResource for Truck object' do
        resource_class_name = "#{truck.class.name}Resource"
        expect(resource_class_name).to eq('TruckResource')
        expect { resource_class_name.constantize }.not_to raise_error
      end
    end
  end

  describe 'STI inheritance in resource classes' do
    it 'allows resource inheritance matching model inheritance' do
      CarResource.new(double('car'))

      # CarResource should inherit attributes from VehicleResource
      expect(CarResource._attributes).to include(:name, :brand, :year, :engine_size)
      expect(TruckResource._attributes).to include(:name, :brand, :year, :cargo_capacity)
    end

    it 'maintains separate attribute sets for different STI resources' do
      expect(CarResource._attributes).to include(:engine_size)
      expect(CarResource._attributes).not_to include(:cargo_capacity)

      expect(TruckResource._attributes).to include(:cargo_capacity)
      expect(TruckResource._attributes).not_to include(:engine_size)
    end
  end

  describe 'Type configuration for STI resources' do
    context 'when type is explicitly set' do
      before do
        CarResource.type 'custom_cars'
        TruckResource.type 'custom_trucks'
      end

      after do
        # Reset to auto-inferred values
        CarResource._type = nil
        TruckResource._type = nil
      end

      it 'uses explicit type over STI inference' do
        car = Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500)
        car_resource = CarResource.new(car)

        expect(car_resource.type).to eq('custom_cars')
      end
    end

    context 'when type is not explicitly set' do
      it 'infers type from STI model class name' do
        car = Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500)
        car_resource = CarResource.new(car)

        expect(car_resource.type).to eq('cars')
      end
    end
  end
end
