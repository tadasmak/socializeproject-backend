types = [
    { name: 'Sports' },
    { name: 'Outdoor' },
    { name: 'Games & Board Games' },
    { name: 'Arts & Culture' },
    { name: 'Food & Drink' },
    { name: 'Fitness & Wellness' },
    { name: 'Social & Entertainment' },
    { name: 'Learning & Hobbies' },
    { name: 'Other' }
]

types.each do |type|
    ActivityType.find_or_create_by!(name: type[:name])
end