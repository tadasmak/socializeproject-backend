DESCRIPTION_MIN_LENGTH = Activities::BusinessRules::DescriptionLengthRule::MIN_LENGTH
DESCRIPTION_MAX_LENGTH = Activities::BusinessRules::DescriptionLengthRule::MAX_LENGTH

class GenerateDescriptionJob < ApplicationJob
  queue_as :default

  def perform(request_id, title, location, start_time)
    return if title.blank?

    formatted_time = begin
      Time.parse(start_time).strftime("%Y-%m-%d %H:%M") if start_time.present?
    rescue ArgumentError
      nil
    end

    prompt = "Here is the activity information:"
    prompt += "- Title: #{title}"
    prompt += "- Location: #{location}" if location.present?
    prompt += "- Start time: #{formatted_time}" if formatted_time.present?

    prompt += "Please write a short, warm, and appealing description (2-3 sentences) that encourages people to join, mentioning the location
              and the upcoming start time in a natural way. The tone should be personal, informal, welcoming, positive, and inclusive, suitable
              for a community of people looking to make friends by participating in activities together.

              Please generate the description in the language the context is provided in. Only keep the generated description in the text.
              Use between #{DESCRIPTION_MIN_LENGTH} and #{DESCRIPTION_MAX_LENGTH} symbols"

    response = HTTParty.post("https://api.groq.com/openai/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{ENV['GROQ_API_KEY']}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [
          { role: "system", content: "You are a creative and friendly assistant who writes engaging and inviting descriptions for social activities." },
          { role: "user", content: prompt }
        ],
        temperature: 0.7
      }.to_json
    )

    if response.ok?
      description = response.parsed_response["choices"].first["message"]["content"].strip
      $redis.set("description:#{request_id}", description, ex: 2.minutes)
    else
      $redis.set("description:#{request_id}", "ERROR", ex: 2.minutes)
    end
  end
end
