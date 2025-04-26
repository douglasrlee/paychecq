# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  # noinspection RailsParamDefResolve
  before_action :set_paper_trail_whodunnit
end
