class ActivitySerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :location, :start_time, :max_participants, :minimum_age, :maximum_age, :created_at, :creator, :participants_count, :status, :activity_type_name
  belongs_to :creator, serializer: UserSerializer
  has_many :participants, serializer: UserSerializer

  def activity_type_name
    object.activity_type&.name
  end
end
