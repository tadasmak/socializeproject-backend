class Api::V1::ActivitiesController < ApplicationController
  include ActivitiesConcern

  skip_before_action :authenticate_user!, only: [ :index, :show ]

  before_action :set_activity, only: [ :show, :update, :destroy, :join, :leave, :update_status ]
  before_action -> { authorize_user!(@activity.creator) }, only: [ :update, :destroy, :update_status ]

  rescue_from ArgumentError, with: :handle_invalid_filtering

  def index
    sorted_params = permitted_activity_filters.sort.to_h
    cache_key = "activities/#{Digest::MD5.hexdigest(sorted_params.to_json)}"
    activities = Rails.cache.fetch(cache_key, expires_in: 1.minute) { gather_activities(sorted_params) }

    render status: :ok, json:  {
      activities: ActiveModelSerializers::SerializableResource.new(
        activities,
        each_serializer: ActivitySerializer
      ),
      page: sorted_params["page"] || 1,
      activities_remain: activities_remain?(sorted_params)
    }
  end

  def show
    render status: :ok, json: @activity, serializer: ActivityDetailSerializer
  end

  def create
    ActiveRecord::Base.transaction do
      attrs = activity_params.to_h
      type_name = attrs.delete("activity_type_name")
      activity_type = ActivityType.find_by!(name: type_name)

      @activity = Activity.create!(attrs.merge(user_id: current_user.id, activity_type:))

      @activity.participant_records.create!(user: current_user)
    end

    render status: :created, json: @activity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e)
  end

  def update
    attrs = activity_params.to_h
    type_name = attrs.delete("activity_type_name")
    activity_type = ActivityType.find_by!(name: type_name)

    @activity.update!(attrs.merge(activity_type:))
    Activities::StatusManager.new(@activity).sync_status

    render status: :ok, json: @activity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e)
  end

  def destroy
    @activity.destroy!

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_errors(e)
  end

  def join
    Activities::ParticipationService.new(@activity, current_user).join!
    render status: :created, json: { message: "You have joined the activity" }
  rescue ActiveRecord::RecordNotUnique => e
    render status: :unprocessable_entity, json: { error: e.message }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_errors(e)
  end

  def leave
    Activities::ParticipationService.new(@activity, current_user).leave!
    render status: :ok, json: { message: "You have left the activity" }
  rescue ActiveRecord::RecordNotFound => e
    render status: :not_found, json: { error: e.message }
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_errors(e)
  end

  def generate_description
    activity_params = params.require(:activity).permit(:title, :location, :start_time)

    title = activity_params[:title]
    location = activity_params[:location]
    start_time = activity_params[:start_time]

    return render status: :bad_request, json: { error: "Title is required" } if title.blank?

    request_id = SecureRandom.uuid
    GenerateDescriptionJob.perform_later(request_id, title, location, start_time)
    render status: :ok, json: { request_id: request_id }
  end

  def description_status
    request_id = params[:request_id]
    return render status: :not_found, json: { error: "Missing request_id" } if request_id.blank?

    key = "description:#{request_id}"
    result = $redis.get(key)

    if result.nil?
      render status: :bad_request, json: { status: "not_found", message: "No such request ID found" }
    elsif result == "PENDING"
      render status: :ok, json: { status: "pending", message: request_id }
    elsif result == "ERROR"
      render status: :unprocessable_entity, json: { status: "error", message: "Description generation failed" }
    else
      render status: :ok, json: { status: "completed", description: result }
    end
  end

  def update_status
    status = params[:status]
    unless Activity.statuses.keys.include?(status)
      return render status: :unprocessable_entity, json: { error: "Invalid or unprovided status" }
    end

    Activities::StatusManager.new(@activity).update_status(status)
    render status: :ok, json: { message: "Activity status updated to #{status}" }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_activity
    @activity = Activity.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render status: :not_found, json: { error: "Activity not found" }
  end

  def permitted_activity_filters
    params.permit(:page, :limit, :q).to_h
  end

  def activity_params
    params.require(:activity).permit(permitted_activity_attributes)
  end

  def permitted_activity_attributes
    [ :title, :description, :location, :start_time, :max_participants, :minimum_age, :maximum_age, :activity_type_name ]
  end

  def render_validation_errors(exception)
    render status: :unprocessable_entity, json: { errors: exception.record.errors.full_messages }
  end

  def handle_invalid_filtering(exception)
    render status: :unprocessable_entity, json: { error: exception.message }
  end
end
