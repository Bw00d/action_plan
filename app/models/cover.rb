class Cover < ApplicationRecord
  has_many :blocks, dependent: :destroy
  belongs_to :plan
  after_create :set_blocks

  def plan
    Plan.find(self.plan_id)
  end

  private
  def set_blocks
      Block.create!(number: 1, blank: true, bottom_padding: '100px', cover_id: self.id)
      Block.create!(number: 2, content: 'Incident Action Plan', font_size: 'h1', font_weight: 'bold', 
                    text_align: 'center', bottom_padding: '25px', cover_id: self.id)
      Block.create!(number: 3, content: self.plan.date.strftime('%B %d, %Y'), font_size: 'h2', font_weight: 'bold', 
                    text_align: 'center',bottom_padding: '20px', cover_id: self.id)
      Block.create!(number: 4, content: '0700 - 2200 ', font_size: 'h2', font_weight: 'bold', 
                    text_align: 'center', bottom_padding: '25px', cover_id: self.id)
      Block.create(number: 5, content: 'ADD AN IMAGE', font_size: 'h2', font_weight: 'bold', 
                   text_align: 'center', bottom_padding: '50px', cover_id: self.id, image_block: true )
      Block.create!(number: 6, content: 'charge code', font_size: 'h3', font_weight: 'bold', 
                    text_align: 'center', cover_id: self.id)
      
    end
end
