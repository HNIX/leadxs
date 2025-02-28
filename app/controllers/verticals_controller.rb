class VerticalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vertical, only: [:show, :edit, :update, :destroy, :archive, :unarchive]

  def index
    @verticals = Vertical.all
    @verticals = @verticals.active unless params[:show_archived] == "true"
    @verticals = @verticals.where(primary_category: params[:category]) if params[:category].present?
    @verticals = @verticals.sorted
  end

  def show
  end

  def new
    @vertical = Vertical.new
    @vertical.base = false
  end

  def edit
  end

  def create
    @vertical = Vertical.new(vertical_params)
    @vertical.base = false # User-created verticals can't be base verticals

    if @vertical.save
      redirect_to @vertical, notice: "Vertical was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @vertical.update(vertical_params)
      redirect_to @vertical, notice: "Vertical was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vertical.destroy
    redirect_to verticals_path, notice: "Vertical was successfully deleted."
  end

  def archive
    @vertical.update(archived: true)
    redirect_to verticals_path, notice: "Vertical was successfully archived."
  end

  def unarchive
    @vertical.update(archived: false)
    redirect_to verticals_path, notice: "Vertical was successfully unarchived."
  end

  private

  def set_vertical
    @vertical = Vertical.find(params[:id])
  end

  def vertical_params
    params.require(:vertical).permit(:name, :primary_category, :secondary_category, :description)
  end
end
