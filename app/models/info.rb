class Info < ApplicationRecord
    validates :title, {presence: true}
    validates :image_url, {presence: true}
    validates :shorten_url, {presence: true}
end
