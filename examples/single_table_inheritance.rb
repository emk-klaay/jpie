# frozen_string_literal: true

# Single Table Inheritance (STI) Example
# This example demonstrates how JPie handles Rails STI models seamlessly

# ==============================================================================
# 1. STI MODELS
# ==============================================================================

# Base model
class Vehicle < ApplicationRecord
  validates :name, presence: true
  validates :brand, presence: true
  validates :year, presence: true, numericality: { greater_than: 1900 }
  
  scope :by_brand, ->(brand) { where(brand: brand) }
  scope :recent, -> { where('year >= ?', 5.years.ago.year) }
  
  def age
    Date.current.year - year
  end
end

# STI subclasses
class Car < Vehicle
  validates :engine_size, presence: true, numericality: { greater_than: 0 }
  validates :doors, presence: true, inclusion: { in: [2, 4, 5] }
  
  scope :compact, -> { where('engine_size <= ?', 2000) }
  scope :luxury, -> { where('engine_size > ?', 3000) }
  
  def fuel_efficiency
    # Simple calculation: smaller engines are more efficient
    base_efficiency = 40 - (engine_size / 200.0)
    [base_efficiency, 10].max.round(1)
  end
end

class Truck < Vehicle
  validates :cargo_capacity, presence: true, numericality: { greater_than: 0 }
  validates :towing_capacity, presence: true, numericality: { greater_than: 0 }
  
  scope :heavy_duty, -> { where('cargo_capacity > ?', 2000) }
  scope :commercial, -> { where('towing_capacity > ?', 5000) }
  
  def payload_ratio
    (cargo_capacity.to_f / towing_capacity * 100).round(1)
  end
end

class Motorcycle < Vehicle
  validates :engine_size, presence: true, numericality: { greater_than: 0 }
  validates :bike_type, presence: true, inclusion: { in: %w[sport touring cruiser dirt] }
  
  scope :sport_bikes, -> { where(bike_type: 'sport') }
  scope :touring_bikes, -> { where(bike_type: 'touring') }
  
  def power_to_weight_ratio
    # Assuming average motorcycle weight based on type
    weight = case bike_type
             when 'sport' then 180
             when 'touring' then 300
             when 'cruiser' then 250
             when 'dirt' then 120
             end
    
    (engine_size.to_f / weight).round(2)
  end
end

# ==============================================================================
# 2. STI RESOURCES
# ==============================================================================

# Base resource
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
  meta_attributes :created_at, :updated_at
  
  # Computed attributes available to all vehicles
  attribute :age
  attribute :vehicle_category
  
  private
  
  def age
    object.age
  end
  
  def vehicle_category
    object.class.name.downcase
  end
end

# STI resources inherit from base resource
class CarResource < VehicleResource
  attributes :engine_size, :doors  # Car-specific attributes
  
  # Car-specific computed attributes
  attribute :fuel_efficiency
  attribute :size_category
  
  private
  
  def fuel_efficiency
    object.fuel_efficiency
  end
  
  def size_category
    case object.engine_size
    when 0..1500
      'compact'
    when 1501..2500
      'mid-size'
    when 2501..3500
      'full-size'
    else
      'luxury'
    end
  end
end

class TruckResource < VehicleResource
  attributes :cargo_capacity, :towing_capacity  # Truck-specific attributes
  
  # Truck-specific computed attributes
  attribute :payload_ratio
  attribute :truck_class
  
  private
  
  def payload_ratio
    object.payload_ratio
  end
  
  def truck_class
    if object.cargo_capacity > 2000 && object.towing_capacity > 5000
      'heavy_duty'
    elsif object.cargo_capacity > 1000
      'medium_duty'
    else
      'light_duty'
    end
  end
end

class MotorcycleResource < VehicleResource
  attributes :engine_size, :bike_type  # Motorcycle-specific attributes
  
  # Motorcycle-specific computed attributes
  attribute :power_to_weight_ratio
  attribute :performance_category
  
  private
  
  def power_to_weight_ratio
    object.power_to_weight_ratio
  end
  
  def performance_category
    ratio = object.power_to_weight_ratio
    case ratio
    when 0..2.0
      'standard'
    when 2.1..4.0
      'performance'
    else
      'high_performance'
    end
  end
end

# ==============================================================================
# 3. STI CONTROLLERS
# ==============================================================================

class VehiclesController < ApplicationController
  include JPie::Controller
  # Returns all vehicles (cars, trucks, motorcycles, etc.) using VehicleResource
  
  def index
    vehicles = Vehicle.all
    
    # Apply filters if provided
    vehicles = vehicles.by_brand(params[:brand]) if params[:brand].present?
    vehicles = vehicles.recent if params[:recent] == 'true'
    
    render_jsonapi(vehicles)
  end
end

class CarsController < ApplicationController
  include JPie::Controller
  # Automatically uses CarResource and scopes to Car model only
  
  def index
    cars = Car.all
    
    # Car-specific filters
    cars = cars.compact if params[:compact] == 'true'
    cars = cars.luxury if params[:luxury] == 'true'
    
    render_jsonapi(cars)
  end
end

class TrucksController < ApplicationController
  include JPie::Controller
  # Automatically uses TruckResource and scopes to Truck model only
  
  def index
    trucks = Truck.all
    
    # Truck-specific filters
    trucks = trucks.heavy_duty if params[:heavy_duty] == 'true'
    trucks = trucks.commercial if params[:commercial] == 'true'
    
    render_jsonapi(trucks)
  end
end

class MotorcyclesController < ApplicationController
  include JPie::Controller
  # Automatically uses MotorcycleResource and scopes to Motorcycle model only
  
  def index
    motorcycles = Motorcycle.all
    
    # Motorcycle-specific filters
    motorcycles = motorcycles.sport_bikes if params[:sport] == 'true'
    motorcycles = motorcycles.touring_bikes if params[:touring] == 'true'
    
    render_jsonapi(motorcycles)
  end
end

# ==============================================================================
# 4. ROUTES FOR STI RESOURCES
# ==============================================================================

# config/routes.rb
Rails.application.routes.draw do
  # All vehicles endpoint
  resources :vehicles, only: [:index, :show]
  
  # Specific vehicle type endpoints
  resources :cars
  resources :trucks
  resources :motorcycles
end

# ==============================================================================
# 5. EXAMPLE API REQUESTS AND RESPONSES
# ==============================================================================

# GET /vehicles
# Response shows all vehicle types with their specific attributes:
{
  "data": [
    {
      "id": "1",
      "type": "cars",  # STI type automatically inferred
      "attributes": {
        "name": "Civic",
        "brand": "Honda", 
        "year": 2020,
        "engine_size": 1500,
        "doors": 4,
        "age": 4,
        "vehicle_category": "car",
        "fuel_efficiency": 32.5,
        "size_category": "compact"
      }
    },
    {
      "id": "2",
      "type": "trucks",  # STI type automatically inferred
      "attributes": {
        "name": "F-150",
        "brand": "Ford",
        "year": 2021,
        "cargo_capacity": 1000,
        "towing_capacity": 6000,
        "age": 3,
        "vehicle_category": "truck",
        "payload_ratio": 16.7,
        "truck_class": "medium_duty"
      }
    },
    {
      "id": "3",
      "type": "motorcycles",  # STI type automatically inferred
      "attributes": {
        "name": "Ninja 650",
        "brand": "Kawasaki",
        "year": 2022,
        "engine_size": 649,
        "bike_type": "sport",
        "age": 2,
        "vehicle_category": "motorcycle",
        "power_to_weight_ratio": 3.61,
        "performance_category": "performance"
      }
    }
  ]
}

# GET /cars
# Response shows only cars with car-specific attributes:
{
  "data": [
    {
      "id": "1",
      "type": "cars",
      "attributes": {
        "name": "Civic",
        "brand": "Honda",
        "year": 2020,
        "engine_size": 1500,
        "doors": 4,
        "age": 4,
        "vehicle_category": "car",
        "fuel_efficiency": 32.5,
        "size_category": "compact"
      }
    }
  ]
}

# GET /trucks
# Response shows only trucks with truck-specific attributes:
{
  "data": [
    {
      "id": "2",
      "type": "trucks",
      "attributes": {
        "name": "F-150",
        "brand": "Ford",
        "year": 2021,
        "cargo_capacity": 1000,
        "towing_capacity": 6000,
        "age": 3,
        "vehicle_category": "truck",
        "payload_ratio": 16.7,
        "truck_class": "medium_duty"
      }
    }
  ]
}

# POST /cars
# Request to create a new car:
{
  "data": {
    "type": "cars",
    "attributes": {
      "name": "Camry",
      "brand": "Toyota",
      "year": 2024,
      "engine_size": 2000,
      "doors": 4
    }
  }
}

# Response (201 Created) - STI handled automatically:
{
  "data": {
    "id": "4",
    "type": "cars",
    "attributes": {
      "name": "Camry",
      "brand": "Toyota", 
      "year": 2024,
      "engine_size": 2000,
      "doors": 4,
      "age": 0,
      "vehicle_category": "car",
      "fuel_efficiency": 30.0,
      "size_category": "mid-size"
    },
    "meta": {
      "created_at": "2024-01-15T14:30:00Z",
      "updated_at": "2024-01-15T14:30:00Z"
    }
  }
}

# ==============================================================================
# 6. ADVANCED STI FEATURES
# ==============================================================================

# Custom resource with STI-aware logic
class SmartVehicleResource < JPie::Resource
  attributes :name, :brand, :year
  
  # Dynamic attributes based on STI type
  attribute :specifications
  attribute :performance_metrics
  
  private
  
  def specifications
    case object
    when Car
      {
        type: 'car',
        engine_size: object.engine_size,
        doors: object.doors,
        fuel_efficiency: object.fuel_efficiency
      }
    when Truck
      {
        type: 'truck',
        cargo_capacity: object.cargo_capacity,
        towing_capacity: object.towing_capacity,
        payload_ratio: object.payload_ratio
      }
    when Motorcycle
      {
        type: 'motorcycle',
        engine_size: object.engine_size,
        bike_type: object.bike_type,
        power_to_weight_ratio: object.power_to_weight_ratio
      }
    else
      {
        type: 'vehicle',
        category: object.class.name.downcase
      }
    end
  end
  
  def performance_metrics
    {
      age: object.age,
      brand_reputation: calculate_brand_reputation,
      efficiency_rating: calculate_efficiency_rating
    }
  end
  
  def calculate_brand_reputation
    # Simple brand scoring
    premium_brands = %w[BMW Mercedes-Benz Audi Lexus]
    reliable_brands = %w[Toyota Honda Subaru Mazda]
    
    if premium_brands.include?(object.brand)
      'premium'
    elsif reliable_brands.include?(object.brand)
      'reliable'
    else
      'standard'
    end
  end
  
  def calculate_efficiency_rating
    case object
    when Car
      object.fuel_efficiency > 30 ? 'excellent' : 'good'
    when Truck
      object.payload_ratio > 20 ? 'excellent' : 'good'
    when Motorcycle
      object.power_to_weight_ratio > 3 ? 'excellent' : 'good'
    else
      'unknown'
    end
  end
end 