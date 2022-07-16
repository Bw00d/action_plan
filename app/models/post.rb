class Post < ApplicationRecord
  attr_accessor :remove_main_image

  # has_rich_text :content
  has_one_attached :main_image
  has_many_attached :other_images
end
