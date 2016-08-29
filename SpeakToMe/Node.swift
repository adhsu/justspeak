class Node {
  var id: Int
  var text: String
  var speaker: String
  var next: Int? // has `next` if there's another message next
  var responses: [Int]? // has `responses` array if user can respond to this
  
  init(id: Int, text: String, speaker: String, next: Int? = nil, responses: [Int]? = nil) {
    self.id = id
    self.text = text
    self.speaker = speaker
    if (next != nil) {
      self.next = next
    }
    if (responses != nil) {
      self.responses = responses
    }
  }
}
