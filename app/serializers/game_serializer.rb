class GameSerializer < ActiveModel::Serializer
  #new 7
  attributes :id, :listing_name, :address, :game_type, :summary,
             :price, :active, :image, :unavailable_dates

  def unavailable_dates
    @instance_options[:unavailable_dates]
  end

  def image
    @instance_options[:image]
  end

  class UserSerializer < ActiveModel::Serializer
    attributes :email, :fullname, :image
  end

  belongs_to :user, serializer: UserSerializer, key: :host
end
