# frozen_string_literal: true

FactoryBot.define do
  factory :bank_account do
    user

    name { Faker::Bank.name }
  end
end
