class ActivityDetailSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :location, :start_time, :max_participants, :minimum_age, :maximum_age, :created_at, :creator, :participants_count, :status, :activity_type
  belongs_to :creator, serializer: UserSerializer
  has_many :participants, serializer: UserSerializer
end
