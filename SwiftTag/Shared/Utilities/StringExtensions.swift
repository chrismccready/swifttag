import Foundation

extension String {
    func truncated(limit: Int, position: String.TruncationPosition = .tail, leader: String = "…") -> String {
        guard self.count > limit else { return self }
        
        switch position {
        case .head:
            return leader + self.suffix(limit)
        case .middle:
            let headCount = Int(ceil(Float(limit - leader.count) / 2.0))
            let tailCount = Int(floor(Float(limit - leader.count) / 2.0))
            return self.prefix(headCount) + leader + self.suffix(tailCount)
        case .tail:
            return self.prefix(limit - leader.count) + leader
        }
    }
    
    enum TruncationPosition {
        case head
        case middle
        case tail
    }
}
