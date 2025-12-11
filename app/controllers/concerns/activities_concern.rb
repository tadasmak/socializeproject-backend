module ActivitiesConcern
  extend ActiveSupport::Concern

  def gather_activities(params)
    process_activities(params)
  end

  def activities_remain?(params)
    next_activity_params = params
    next_page = (next_activity_params["page"].presence&.to_i || 1) + 1
    limit = next_activity_params["limit"].presence&.to_i || 10

    next_activity_params["offset"] = calculate_offset(next_page, limit)

    process_activities(next_activity_params).count > 0
  end

  private

  def filter_offset(result, offset)
    result.offset(offset)
  end

  def filter_limit(result, limit)
    raise ArgumentError, "Limit must be between 1-10" unless 0 < limit && limit <= 10

    result.limit(limit)
  end

  def filter_query(result, query)
    return result unless query.present?

    query = query.downcase
    result.where("LOWER(title) LIKE :query OR
                  LOWER(description) LIKE :query OR
                  LOWER(location) LIKE :query",
                  query: "%#{query}%")
  end

  def process_activities(params)
    result = Activity.all

    query = params["q"].presence
    result = filter_query(result, query)

    # Activities pagination
    page = params["page"].presence&.to_i || 1
    limit = params["limit"].presence&.to_i || 10
    offset = params["offset"].presence&.to_i || calculate_offset(page, limit)

    result = filter_offset(result, offset)
    result = filter_limit(result, limit)
  end

  def calculate_offset(page, limit)
    (page - 1) * limit
  end
end
