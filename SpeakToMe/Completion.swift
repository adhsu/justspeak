import Foundation

class Completion {
  
  var cancelled: Bool = false
  var timestamp: UInt64?
  init(_ timestamp: UInt64) {
    self.timestamp = timestamp
    print("initing a Completion class, timestamp is \(self.timestamp)")
  }
  
}
