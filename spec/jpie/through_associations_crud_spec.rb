# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JPie Through Associations CRUD Handling', type: :request do
  # Test models for through associations
  let!(:car) { Car.create!(make: 'Toyota', model: 'Camry', year: 2022) }
  let!(:driver) { Driver.create!(name: 'John Doe', license_number: 'ABC123') }

  describe 'Through Association Creation' do
    context 'when creating a car-driver relationship' do
      it 'automatically creates the join table record' do
        car_driver_params = {
          data: {
            type: 'car_drivers',
            attributes: {},
            relationships: {
              car: {
                data: { type: 'cars', id: car.id.to_s }
              },
              driver: {
                data: { type: 'drivers', id: driver.id.to_s }
              }
            }
          }
        }

        post '/car_drivers',
             params: car_driver_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)
        
        # Verify the join record was created
        car_driver = CarDriver.last
        expect(car_driver.car).to eq(car)
        expect(car_driver.driver).to eq(driver)
        
        # Verify through associations work
        expect(car.drivers).to include(driver)
        expect(driver.cars).to include(car)
      end
    end

    context 'when creating car-driver via nested route' do
      it 'automatically sets the parent association' do
        driver_params = {
          data: {
            type: 'car_drivers',
            attributes: {},
            relationships: {
              driver: {
                data: { type: 'drivers', id: driver.id.to_s }
              }
            }
          }
        }

        post "/cars/#{car.id}/car_drivers",
             params: driver_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)
        
        car_driver = CarDriver.last
        expect(car_driver.car).to eq(car)
        expect(car_driver.driver).to eq(driver)
      end
    end
  end

  describe 'Through Association Includes' do
    let!(:car_driver) { CarDriver.create!(car: car, driver: driver) }

    it 'includes through associations in car response' do
      get "/cars/#{car.id}?include=drivers",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      
      # Check main resource
      expect(response_data['data']['id']).to eq(car.id.to_s)
      expect(response_data['data']['type']).to eq('cars')
      
      # Check included drivers (through association)
      included_drivers = response_data['included'].select { |r| r['type'] == 'drivers' }
      expect(included_drivers.size).to eq(1)
      expect(included_drivers.first['id']).to eq(driver.id.to_s)
      expect(included_drivers.first['attributes']['name']).to eq('John Doe')
      
      # Join table should NOT be exposed in the API
      car_drivers = response_data['included'].select { |r| r['type'] == 'car_drivers' }
      expect(car_drivers).to be_empty
    end

    it 'includes through associations in driver response' do
      get "/drivers/#{driver.id}?include=cars",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      included_cars = response_data['included'].select { |r| r['type'] == 'cars' }
      expect(included_cars.size).to eq(1)
      expect(included_cars.first['id']).to eq(car.id.to_s)
    end
  end

  describe 'Through Association Updates' do
    let!(:car_driver) { CarDriver.create!(car: car, driver: driver) }

    it 'updates join table records via direct endpoint' do
      # Add metadata fields to the join table
      update_params = {
        data: {
          id: car_driver.id.to_s,
          type: 'car_drivers',
          attributes: {
            # If CarDriver had additional fields like start_date, notes, etc.
            # primary_driver: true
          }
        }
      }

      patch "/car_drivers/#{car_driver.id}",
            params: update_params.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      # Associations should remain intact
      car_driver.reload
      expect(car_driver.car).to eq(car)
      expect(car_driver.driver).to eq(driver)
    end
  end

  describe 'Through Association Deletion' do
    let!(:car_driver) { CarDriver.create!(car: car, driver: driver) }

    it 'removes through association by deleting join record' do
      expect {
        delete "/car_drivers/#{car_driver.id}",
               headers: { 'Accept' => 'application/vnd.api+json' }
      }.to change(CarDriver, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      
      # Through associations should be removed
      car.reload
      driver.reload
      expect(car.drivers).not_to include(driver)
      expect(driver.cars).not_to include(car)
    end

    it 'removes association via nested route' do
      expect {
        delete "/cars/#{car.id}/car_drivers/#{car_driver.id}",
               headers: { 'Accept' => 'application/vnd.api+json' }
      }.to change(CarDriver, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'Multiple Through Associations' do
    let!(:another_driver) { Driver.create!(name: 'Jane Smith', license_number: 'XYZ789') }
    let!(:car_driver1) { CarDriver.create!(car: car, driver: driver) }
    let!(:car_driver2) { CarDriver.create!(car: car, driver: another_driver) }

    it 'handles multiple drivers for one car' do
      get "/cars/#{car.id}?include=drivers",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      included_drivers = response_data['included'].select { |r| r['type'] == 'drivers' }
      expect(included_drivers.size).to eq(2)
      
      driver_names = included_drivers.map { |d| d['attributes']['name'] }
      expect(driver_names).to include('John Doe', 'Jane Smith')
    end
  end

  describe 'Nested Through Association Creation' do
    let!(:another_car) { Car.create!(make: 'Honda', model: 'Civic', year: 2021) }

    it 'creates multiple car-driver relationships' do
      # Driver drives multiple cars
      car_driver_params1 = {
        data: {
          type: 'car_drivers',
          attributes: {},
          relationships: {
            car: { data: { type: 'cars', id: car.id.to_s } },
            driver: { data: { type: 'drivers', id: driver.id.to_s } }
          }
        }
      }

      car_driver_params2 = {
        data: {
          type: 'car_drivers',
          attributes: {},
          relationships: {
            car: { data: { type: 'cars', id: another_car.id.to_s } },
            driver: { data: { type: 'drivers', id: driver.id.to_s } }
          }
        }
      }

      # Create first relationship
      post '/car_drivers',
           params: car_driver_params1.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }
      expect(response).to have_http_status(:created)

      # Create second relationship
      post '/car_drivers',
           params: car_driver_params2.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }
      expect(response).to have_http_status(:created)

      # Verify driver has access to both cars
      driver.reload
      expect(driver.cars).to include(car, another_car)
      expect(driver.cars.count).to eq(2)
    end
  end

  describe 'Error Handling for Through Associations' do
    it 'returns validation error for duplicate car-driver relationship' do
      CarDriver.create!(car: car, driver: driver)
      
      duplicate_params = {
        data: {
          type: 'car_drivers',
          attributes: {},
          relationships: {
            car: { data: { type: 'cars', id: car.id.to_s } },
            driver: { data: { type: 'drivers', id: driver.id.to_s } }
          }
        }
      }

      post '/car_drivers',
           params: duplicate_params.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      response_data = JSON.parse(response.body)
      expect(response_data['errors']).to be_present
    end

    it 'returns not found for non-existent car in nested route' do
      driver_params = {
        data: {
          type: 'car_drivers',
          attributes: {},
          relationships: {
            driver: { data: { type: 'drivers', id: driver.id.to_s } }
          }
        }
      }

      post '/cars/99999/car_drivers',
           params: driver_params.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:not_found)
    end
  end
end 