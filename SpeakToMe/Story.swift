// singleton class to create a Story and construct its nodes

import Foundation

class Story {
  static let sharedInstance = Story()
  
  let sceneIds: [Int] = [2, 27, 63]
  var currentSceneIndex: Int = 0 // tracks index of current scene, sceneIds[currentScene] is the acutal node id
  
  var currentSceneStartingId: Int {
    return sceneIds[currentSceneIndex]
  }

  var rootNodeId: Int {
    return sceneIds[0]
  }
  var currentNodeId: Int = 1
  
  var nodes: [Int: Node] = [:] // dictionary of nodes, will construct in viewDidLoad

  private init() {
    print("~~~~initing a Story~~~~")
    
    // read story.txt from file
    var dataArr: [String] = []
    do {
      if let filePath = Bundle.main.path(forResource: "story", ofType: "txt") {
        let data = try String(contentsOfFile: filePath, encoding: String.Encoding.utf8)
        dataArr = data.components(separatedBy: NSCharacterSet.newlines).filter { !($0.isEmpty) } // separate by newline and filter out empty strings
      }
    } catch let err as NSError {
      print(err)
    }
    // construct self.nodes dictionary
    self.constructNodesDict(dataArr)
    // print(nodes)

  }

  func constructNodesDict(_ dataArr: [String]) {
    for line in dataArr {
      let id: Int = Int(line.components(separatedBy: ":")[0].trimmingCharacters(in: CharacterSet.whitespaces))!
      // print("stm: got id: \(id)")
      // let id = line.characters.split {$0 == ":"}.map(String.init)[0]
      var message: String = line // start message off with full line, will cut down to real message
      
      // cut starting id
      message = message.components(separatedBy: ":")[1].trimmingCharacters(in: CharacterSet.whitespaces)
      
      if let arrowRange = message.range(of: "->") { // check for 'next'
        // extract next int
        let next: Int = Int(message.substring(from: arrowRange.upperBound).trimmingCharacters(in: CharacterSet.whitespaces))!
        // print("stm: got next: \(next)")
        
        // extract message + speaker
        message = message.substring(to: arrowRange.lowerBound).trimmingCharacters(in: CharacterSet.whitespaces)
        
        if let parenIdx = message.range(of: ")") {
          let speaker = message.substring(to: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.init(charactersIn: "()"))
          // print("stm: got speaker: \(speaker)")
          
          message = message.substring(from: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.whitespaces)
          // print("stm: message: \(message)")
          
          // create the node and add to self.nodes
          nodes[id] = Node(
            id: id,
            text: message,
            speaker: speaker,
            next: next
          )
          
        }
        
      } else if let responseIdx = message.range(of: "[") { // check for responses
        // extract responses array
        let responses = message.substring(from: responseIdx.upperBound).trimmingCharacters(in: CharacterSet.init(charactersIn: "[]")).components(separatedBy: ",")
        let responsesArr = responses.map { Int($0.trimmingCharacters(in: CharacterSet.whitespaces))! }
        // print("stm: got responses: \(responses)")
        
        // extract message + speaker
        message = message.substring(to: responseIdx.lowerBound).trimmingCharacters(in: CharacterSet.whitespaces)
        
        if let parenIdx = message.range(of: ")") {
          let speaker = message.substring(to: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.init(charactersIn: "()"))
          // print("stm: got speaker: \(speaker)")
          
          message = message.substring(from: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.whitespaces)
          // print("stm: message: \(message)")
          
          // create the node and add to self.nodes
          nodes[id] = Node(
            id: id,
            text: message,
            speaker: speaker,
            responses: responsesArr
          )
        }
      } else { // end of story
        if let parenIdx = message.range(of: ")") {
          let speaker = message.substring(to: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.init(charactersIn: "()"))
          // print("stm: got speaker: \(speaker)")
          
          message = message.substring(from: parenIdx.upperBound).trimmingCharacters(in: CharacterSet.whitespaces)
          // print("stm: message: \(message)")
          
          // create the node and add to self.nodes
          nodes[id] = Node(
            id: id,
            text: message,
            speaker: speaker
          )
        }
      }
      // print("stm: --")
    }
  }
  
}
