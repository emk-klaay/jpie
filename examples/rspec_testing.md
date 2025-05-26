# Testing JPie Resources with RSpec

This guide demonstrates how to use JPie's RSpec matchers and helpers to test your JSON:API resources.

## Setup

Add to your `spec/rails_helper.rb` or `spec/spec_helper.rb`:

```ruby
require 'jpie/rspec'
JPie::RSpec.configure!
```

## Example Usage

Given a basic resource setup:

```ruby
# app/models/book.rb
class Book < ApplicationRecord
  belongs_to :author
  has_many :reviews
  
  def reading_time_minutes
    (content.split.length / 200.0).ceil
  end
end

# app/resources/book_resource.rb
class BookResource < JPie::Resource
  type :books
  
  attribute :title
  meta_attribute :reading_time
  relationship :author
  relationship :reviews
  
  def reading_time
    { minutes: object.reading_time_minutes }
  end
end
```

Here's how to test it:

```ruby
# spec/resources/book_resource_spec.rb
RSpec.describe BookResource, type: :resource do
  let(:author) { create(:author) }
  let(:book) { create(:book, author: author) }
  let(:resource) { described_class.new(model: book) }

  # Test resource structure
  it { is_expected.to have_type(:books) }
  it { is_expected.to have_attribute(:title) }
  it { is_expected.to have_meta_attribute(:reading_time) }
  it { is_expected.to have_relationship(:author) }
  it { is_expected.to have_relationship(:reviews) }

  # Test meta values
  it 'has correct reading time' do
    expect(resource).to have_meta_value(:reading_time).including(
      minutes: book.reading_time_minutes
    )
  end

  # Test relationship linkage
  it 'has correct author linkage' do
    expect(resource).to have_relationship_linkage(:author).with_id(author.id.to_s)
  end
end

# spec/requests/books_controller_spec.rb
RSpec.describe BooksController, type: :request do
  let!(:books) { create_list(:book, 10) }

  describe 'GET /books' do
    it 'handles pagination and includes' do
      get '/books', params: { 
        page: 1, 
        per_page: 5,
        include: 'author,reviews'
      }
      
      # Test pagination
      expect(response).to be_paginated
      expect(response).to have_page_size(5)
      expect(response).to have_pagination_links.including(:first, :last, :next)

      # Test includes
      expect(response).to include_related(:author)
      expect(response).to include_related(:reviews)
    end
  end
end
```

## Helper Methods

```ruby
# Build without saving
book = build_jpie_resource(:books, { title: 'Test Book' })

# Create with relationships
author = create_jpie_resource(:authors, { name: 'Author' })
book = create_jpie_resource(:books, { title: 'Test Book' }, { author: author })

# Clean up
cleanup_jpie_resources([book, author])
```

## Best Practices

1. Always clean up your test resources using `cleanup_jpie_resources`
2. Test both the presence of attributes/relationships and their values
3. Group your tests logically by resource features (attributes, relationships, meta)
4. Test pagination with different page sizes and page numbers
5. Test relationship includes with various combinations
6. Test meta fields with both simple and complex values
7. Use factories (like FactoryBot) to create test data
8. Test edge cases and validations specific to your resource configuration

## Common Gotchas

- Remember that `have_attribute` and `have_relationship` check both the presence of the method and the attribute/relationship in the resource's configuration
- The cleanup helper will only destroy persisted resources
- When testing relationships, make sure to test both the relationship configuration and the actual related resources
- Meta field values should match exactly, including nested structures
- Pagination tests should verify both the metadata and the actual number of records returned
- When testing includes, verify both the presence of the included data and its structure 