# frozen_string_literal: true

::FactoryBot.define do
  factory :user do
    name { ::Faker::Name.name }
    email { ::Faker::Internet.unique.email }
    password { ::Faker::Internet.password }
  end
end
