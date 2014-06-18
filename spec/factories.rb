FactoryGirl.define do
  factory :user do
    name 'John'
    slug 'john-doe'
  end

  factory :movie do
    name 'movie'
    slug 'movie-1234'
    year '1234'
  end
end
