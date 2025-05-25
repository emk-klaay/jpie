# frozen_string_literal: true

# Through Associations Example
# This example demonstrates how to use Rails' :through associations with JPie resources

# ==============================================================================
# 1. MODELS WITH THROUGH ASSOCIATIONS
# ==============================================================================

class Car < ApplicationRecord
  has_many :car_drivers, dependent: :destroy
  has_many :drivers, through: :car_drivers
  
  validates :make, :model, :year, presence: true
end

class Driver < ApplicationRecord
  has_many :car_drivers, dependent: :destroy
  has_many :cars, through: :car_drivers
  
  validates :name, :license_number, presence: true
end

class CarDriver < ApplicationRecord
  belongs_to :car
  belongs_to :driver
  
  # Optional: Add metadata to the join table
  # For example: start_date, end_date, primary_driver flag, etc.
  validates :car, :driver, presence: true
end

# ==============================================================================
# 2. RESOURCES WITH THROUGH ASSOCIATIONS
# ==============================================================================

class CarResource < JPie::Resource
  attributes :make, :model, :year
  meta_attributes :created_at, :updated_at

  # This is the key: JPie supports :through associations directly
  has_many :drivers, through: :car_drivers
end

class DriverResource < JPie::Resource
  attributes :name, :license_number
  meta_attributes :created_at, :updated_at

  # Reverse through association also works
  has_many :cars, through: :car_drivers
end

# ==============================================================================
# 3. CONTROLLERS
# ==============================================================================

class CarsController < ApplicationController
  include JPie::Controller
  # Automatic CRUD with through association support
end

class DriversController < ApplicationController
  include JPie::Controller
  # Automatic CRUD with through association support
end

class CarDriversController < ApplicationController
  include JPie::Controller
  
  # Custom controller for managing the many-to-many relationships
  def create
    car = Car.find(params[:car_id])
    driver = Driver.find(driver_params[:driver_id])
    
    car_driver = car.car_drivers.build(driver: driver)
    car_driver.save!
    
    render_jsonapi(car_driver, status: :created)
  end
  
  private
  
  def driver_params
    deserialize_params.permit(:driver_id)
  end
end

# ==============================================================================
# 4. ROUTES
# ==============================================================================

# config/routes.rb
Rails.application.routes.draw do
  resources :cars do
    resources :car_drivers, only: [:index, :create, :destroy]
  end
  
  resources :drivers do
    resources :car_drivers, only: [:index, :create, :destroy]
  end
  
  resources :car_drivers, only: [:show, :update, :destroy]
end

# ==============================================================================
# 5. EXAMPLE API REQUESTS AND RESPONSES
# ==============================================================================

# GET /cars/1?include=drivers
# Response shows car with associated drivers (no car_drivers exposed):
{
  "data": {
    "id": "1",
    "type": "cars",
    "attributes": {
      "make": "Toyota",
      "model": "Camry",
      "year": 2022
    },
    "meta": {
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "drivers",
      "attributes": {
        "name": "John Doe",
        "license_number": "ABC123"
      }
    },
    {
      "id": "2", 
      "type": "drivers",
      "attributes": {
        "name": "Jane Smith",
        "license_number": "XYZ789"
      }
    }
  ]
}

# GET /drivers/1?include=cars
# Response shows driver with associated cars:
{
  "data": {
    "id": "1",
    "type": "drivers",
    "attributes": {
      "name": "John Doe",
      "license_number": "ABC123"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "cars",
      "attributes": {
        "make": "Toyota",
        "model": "Camry", 
        "year": 2022
      }
    },
    {
      "id": "2",
      "type": "cars", 
      "attributes": {
        "make": "Honda",
        "model": "Civic",
        "year": 2021
      }
    }
  ]
}

# ==============================================================================
# 6. ADVANCED THROUGH ASSOCIATIONS
# ==============================================================================

# Custom relationship names with through associations
class VehicleResource < JPie::Resource
  attributes :make, :model, :year
  
  # Use a custom relationship name with through
  has_many :operators, through: :car_drivers, attr: :drivers, resource: 'DriverResource'
  
  # This allows:
  # GET /vehicles/1?include=operators
  # Instead of using 'drivers', the API uses 'operators'
end

# Nested through associations
class CompanyResource < JPie::Resource
  attributes :name, :address
  
  has_many :cars
  # Through cars -> car_drivers -> drivers
  has_many :all_drivers, through: :cars, attr: :drivers, resource: 'DriverResource'
  
  # This enables:
  # GET /companies/1?include=all_drivers
  # To get all drivers across all company cars
end 