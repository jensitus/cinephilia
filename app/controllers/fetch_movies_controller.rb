class FetchMoviesController < ApplicationController
  def get
    Movie.set_date
    head 201
  end
end
