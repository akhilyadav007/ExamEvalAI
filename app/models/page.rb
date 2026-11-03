class Page < ApplicationRecord
  belongs_to :answer_book
  has_one_attached :image
  has_many :regions, -> { order(:label_index) }, dependent: :destroy
end
