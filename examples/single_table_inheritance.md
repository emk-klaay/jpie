# Single Table Inheritance (STI) Example

This example demonstrates the minimal setup required to implement Single Table Inheritance with JPie resources and controllers.

## Setup

### 1. Base Model (`app/models/vehicle.rb`)
```ruby
class Vehicle < ApplicationRecord
  validates :name, presence: true
  validates :brand, presence: true
  validates :year, presence: true
end
```

### 2. STI Models (`app/models/car.rb`, `app/models/truck.rb`)
```ruby
class Car < Vehicle
  validates :engine_size, presence: true
end

class Truck < Vehicle
  validates :cargo_capacity, presence: true
end
```

### 3. Base Resource (`app/resources/vehicle_resource.rb`)
```ruby
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
end
```

### 4. STI Resources (`app/resources/car_resource.rb`, `app/resources/truck_resource.rb`)
```ruby
class CarResource < VehicleResource
  attributes :engine_size
end

class TruckResource < VehicleResource
  attributes :cargo_capacity
end
```

### 5. Controller (`app/controllers/vehicles_controller.rb`)
```ruby
class VehiclesController < ApplicationController
  include JPie::Controller
end
```

### 6. Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  resources :vehicles
end
```

## HTTP Examples

### Create Car
```http
POST /vehicles
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "cars",
    "attributes": {
      "name": "Civic",
      "brand": "Honda",
      "year": 2024,
      "engine_size": 1500
    }
  }
}

HTTP/1.1 201 Created
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "cars",
    "attributes": {
      "name": "Civic",
      "brand": "Honda",
      "year": 2024,
      "engine_size": 1500
    }
  }
}
```

### Update Car
```http
PATCH /vehicles/1
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "cars",
    "attributes": {
      "name": "Civic Hybrid",
      "engine_size": 1800
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "cars",
    "attributes": {
      "name": "Civic Hybrid",
      "brand": "Honda",
      "year": 2024,
      "engine_size": 1800
    }
  }
}
```

### Get Mixed Vehicles
```http
GET /vehicles
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "1",
      "type": "cars",
      "attributes": {
        "name": "Civic",
        "brand": "Honda",
        "year": 2024,
        "engine_size": 1500
      }
    },
    {
      "id": "2",
      "type": "trucks",
      "attributes": {
        "name": "F-150",
        "brand": "Ford",
        "year": 2024,
        "cargo_capacity": 1000
      }
    }
  ]
}
``` 