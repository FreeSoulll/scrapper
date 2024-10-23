class ShopsController < ApplicationController
  load_and_authorize_resource

  def index
    @shops = Shop.accessible_by(current_ability)
  end

  def show; end
  def new; end

  def create
    @shop = current_user.shops.new(shop_params)

    if @shop.save
      redirect_to user_path, notice: 'show was created'
    else
      render 'user/index'
    end
  end

  def edit; end

  def update
    if @shop.update(shop_params)
      redirect_to @shop, notice: 'shop was update'
    else
      redner :edit
    end
  end

  def destroy
    @shop.destroy
    redirect_to shops_url, notice: 'show was delete'
  end

  private

  def shop_params
    params.require(:shop).permit(:shop_title, :api_token_shop, :api_token_password)
  end
end
