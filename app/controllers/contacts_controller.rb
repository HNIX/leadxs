class ContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_contact, only: [:show, :edit, :update, :destroy]

  def index
    @contacts = @company.contacts.sorted
  end

  def show
  end

  def new
    @contact = @company.contacts.new
  end

  def edit
  end

  def create
    @contact = @company.contacts.new(contact_params)

    if @contact.save
      respond_to do |format|
        format.html { redirect_to company_contact_path(@company, @contact), notice: "Contact was successfully created." }
        format.turbo_stream { redirect_to company_path(@company), notice: "Contact was successfully created." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @contact.update(contact_params)
      respond_to do |format|
        format.html { redirect_to company_contact_path(@company, @contact), notice: "Contact was successfully updated." }
        format.turbo_stream { redirect_to company_path(@company), notice: "Contact was successfully updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.destroy
    redirect_to company_path(@company), notice: "Contact was successfully deleted."
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_contact
    @contact = @company.contacts.find(params[:id])
  end

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :email, :phone)
  end
end
