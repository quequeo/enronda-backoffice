class ProfessionalsController < ApplicationController
  require 'will_paginate/array'

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

  def events
    filter_params = params.permit!.slice(:status, :start_date, :end_date)
    @professional = Professional.find(params[:id])
    @events = CalendlyService.professional_events(@professional, filter_params)
    @events_count = @events.count
    @events = @events.paginate(page: params[:page], per_page: 15)
    @events
  end

  def events_csv
    filter_params = params.permit!.slice(:status, :start_date, :end_date)
    @professional = Professional.find(params[:id])
    events = CalendlyService.professional_events(@professional, filter_params)

    respond_to do |format|
      format.csv do
        send_data generate_csv_data(events), filename: "#{@professional.name.downcase.parameterize}_events_#{Date.today}.csv"
      end
    end
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

  def generate_csv_data(events)
    CSV.generate do |csv|
      csv << ['Professional Name', 'Event Name', 'Created At', 'Start Time', 'End Time', 'Status']
      
      events.each do |event|
        if event.is_a?(Hash) && event[:error]
          csv << [event[:professional_name], event[:error], 'N/A', 'N/A', 'N/A', 'N/A']
        else
          csv << [
            event['event_memberships'][0]['user_name'],
            event['name'],
            Time.parse(event['created_at']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            Time.parse(event['start_time']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            Time.parse(event['end_time']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            event['status'].capitalize
          ]
        end
      end
    end
  end
end