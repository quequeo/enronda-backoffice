class ProfessionalsController < ApplicationController
    def index
      @professionals = Professional.all
    end
  
    def new
      @professional = Professional.new
    end
  
    def create
      @professional = Professional.new(professional_params)
      if @professional.save
        redirect_to professionals_path, notice: 'Professional was successfully created.'
      else
        render :new
      end
    end

    def show
      @professional = Professional.find(params[:id])
    end
  
    def edit
      @professional = Professional.find(params[:id])
    end
  
    def update
      @professional = Professional.find(params[:id])
      if @professional.update(professional_params)
        redirect_to professionals_path, notice: 'Professional was successfully updated.'
      else
        render :edit
      end
    end
  
    def destroy
      @professional = Professional.find(params[:id])
      @professional.destroy
      redirect_to professionals_path, notice: 'Professional was successfully destroyed.'
    rescue ActiveRecord::RecordNotFound
      nil
    end
  
    private
  
    def professional_params
      params.require(:professional).permit(:name, :token, :phone, :email)
    end
  end