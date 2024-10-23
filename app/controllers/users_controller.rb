class UsersController < ApplicationController
  def index
    @user = current_user
    @shop = Shop.new
  end
end