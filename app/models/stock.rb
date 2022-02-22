class Stock < ApplicationRecord
    def infos
        return @infos = Info.where(stock_id: self.id)
    end
end
