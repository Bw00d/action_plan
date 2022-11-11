class Block < ApplicationRecord
  belongs_to :cover 
  acts_as_list scope: :cover
  attr_accessor :remove_main_image

  has_one_attached :main_image
  has_many_attached :other_images

end
