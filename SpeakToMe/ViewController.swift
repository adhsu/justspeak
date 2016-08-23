/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The primary view controller. The speach-to-text engine is managed an configured here.
*/

import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
  // MARK: Properties
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  
  private var r1Translate : CGFloat?
  private var r2Translate : CGFloat?
  private var r3Translate : CGFloat?
  
  @IBOutlet var textView : UITextView!
  @IBOutlet var recordButton : UIButton!
  @IBOutlet var restartButton : UIButton!
  @IBOutlet var storyScrollView : UIScrollView!
  
  @IBOutlet var responseStack : UIStackView!
  @IBOutlet var response1 : ResponseTextView!
  @IBOutlet var response2 : ResponseTextView!
  @IBOutlet var response3 : ResponseTextView!
  
  @IBOutlet weak var recordingStatus: UILabel!

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
  
  var currentNodeId: Int = 1
  var currentNode: Node? {
    print("stm: recalculating currentNode")
    return self.nodes[self.currentNodeId]
  }
  var nodes: [Int: Node] = [:] // dictionary of nodes, will construct in viewDidLoad
  var recordingStopped: Bool = false

  
  // MARK: UIViewController
  
  override public func viewDidLoad() {
    // called once when controller loads view into memory, do things you have to do only once
    print("stm: viewDidLoad()")
    super.viewDidLoad()

    // Disable the record buttons until authorization has been granted.
    recordButton.isEnabled = false
    textView.isHidden = true // hide transcript view, not needed right now
    
    
    
    // set up response padding
    let responsePadding: CGFloat = 20.0
    response1.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    response2.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    response3.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    
    // set responses off screen to animate onscreen in viewDidAppear()
    responseStack.isHidden = true
    
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
    constructNodesDict(dataArr)
    print(nodes)
  }
  
  
  override public func viewWillAppear(_ animated: Bool) {
    // called every time just before view is displayed/visible to user. always after viewDidLoad(). set up app state/view data here.
    print("stm: viewWillAppear()")
    super.viewWillAppear(animated)
    
  }
  
  override public func viewDidLayoutSubviews() {
    // called after sizes (frames/bounds/etc) calculated. views already laid out by autolayout. handle anything dependent on bounds here.
    print("stm: viewDidLayoutSubviews()")
    super.viewDidLayoutSubviews()
    
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    // view fully appears
    print("stm: viewDidAppear()")
    
    resetAndInitializeStoryView()
    
    // speech stuff
    speechRecognizer.delegate = self
    
    SFSpeechRecognizer.requestAuthorization { authStatus in
        /*
            The callback may not be called on the main thread. Add an
            operation to the main queue to update the record button's state.
        */
      OperationQueue.main.addOperation {
        switch authStatus {
          case .authorized:
            self.recordButton.isEnabled = true

          case .denied:
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

          case .restricted:
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

          case .notDetermined:
            self.recordButton.isEnabled = false
            self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
        }
      }
    }
  }
  
  
  private func startRecording() throws {

    // Cancel the previous task if it's running.
    if let recognitionTask = recognitionTask {
        recognitionTask.cancel()
        self.recognitionTask = nil
    }
    
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSessionCategoryRecord)
    try audioSession.setMode(AVAudioSessionModeMeasurement)
    try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
    
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    
    guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
    
    // Configure request so that results are returned before audio recording is finished
    recognitionRequest.shouldReportPartialResults = true
    
    // A recognition task represents a speech recognition session.
    // We keep a reference to the task so that it can be cancelled.
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      var isFinal = false
      
      if let result = result {
        self.textView.text = result.bestTranscription.formattedString
        isFinal = result.isFinal
      }
      
      if error != nil || isFinal {
        print("okay error or isfinal")
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
        
        self.recordButton.isEnabled = true
        self.recordButton.setTitle("Start Recording", for: [])
      }
    }
    
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
        self.recognitionRequest?.append(buffer)
    }
    
    audioEngine.prepare()
    
    try audioEngine.start()
    
    textView.text = "(Go ahead, I'm listening)"
  }

  // MARK: SFSpeechRecognizerDelegate

  private func matchScore(bestGuess: String, node: Node) -> Int {
    // Fuzzy match between transcription and children
    var count: Int = 0
    let splitDialog: Array = node.text.characters.split{$0 == " "}.map(String.init)
    var realWordsDialog = [String]()
    for word in splitDialog {
      if word.characters.count > 3 {
        realWordsDialog.append(word)
      }
    }
    count = realWordsDialog.filter({ (bestGuess.lowercased().range(of: $0.lowercased()) != nil) }).count
    return count
  }
    
  private func startListeningLoop() throws {
      
    print("--diagnostic--")
    print(self.recognitionRequest)
    print(self.recognitionTask)
    print(audioEngine.inputNode)
    print("----")
    self.recordingStopped = false
    // Cancel the previous task if it's running.
    if let recognitionTask = recognitionTask {
      print("cancelling recognitionTask")
      recognitionTask.cancel()
      self.recognitionTask = nil
    }
    
    var completedMatch = false
    var crossedThreshold = false
    
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSessionCategoryRecord)
    try audioSession.setMode(AVAudioSessionModeMeasurement)
    try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
    // Configure request so that results are returned before audio recording is finished
    recognitionRequest.shouldReportPartialResults = true
    recordingStatus.text = "Recording..."
    
    print(self.recognitionRequest)
    print(self.recognitionTask)
    print(inputNode)

    // A recognition task represents a speech recognition session.
    // We keep a reference to the task so that it can be cancelled.
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      if !self.recordingStopped { // if we're recording
        var isFinal = false
            
        // we have a new transcription result 
        if let result = result, let currentNode = self.nodes[self.currentNodeId] {
          let bestGuess = result.bestTranscription.formattedString
          print("best guess is... " + bestGuess)
          var highestMatch: (index: Int?, matchCount: Int) = (nil, 0)
          // iterate through all children and rank matchScores
          for (idx, responseId) in (currentNode.responses?.enumerated())! {
            // matchScore is the total number of words we've matched
            let responseNode = self.nodes[responseId]!
            let matchCount = self.matchScore(bestGuess: bestGuess, node: responseNode)
            // this new dialog option is the best match so far
            if highestMatch.matchCount < matchCount {
              highestMatch = (idx, matchCount)
              print(responseNode.text)
            }
          }
              
          if highestMatch.matchCount > 0 {
            
            let responseNodeId = currentNode.responses?[highestMatch.index!]
            if let highlightedResponseNode: Node = self.nodes[responseNodeId!] {
              print("new highlight: " + highlightedResponseNode.text)
              // if our transcript length is approaching the length of the best guess dialog option, move along the dialog
              let dialogCount: Int = highlightedResponseNode.text.characters.count
              let transcriptCount = bestGuess.characters.count
              
              print("dialog chars: \(dialogCount), transcript chars: \(transcriptCount)")
              self.setResponseHighlight(responseIdx: highestMatch.index!, count: min(dialogCount, transcriptCount))
              
              func advance() {
                inputNode.removeTap(onBus: 0)
                // advance currentNode forward
                self.currentNodeId = responseNodeId!
                self.responseSelectedByAudio(node: highlightedResponseNode)
                self.stopListeningLoop()
                self.playResponse()
              }
              
              let completionPercentage: Float = Float(transcriptCount)/Float(dialogCount)
              if completionPercentage > 0.75 {
                print("we have a match of at least 75%.")
                
                if !crossedThreshold {
                  print("triggering delayed advance, should only happen once***********")
                  self.delay(seconds: 5.0) {
                    if !completedMatch {
                      advance()
                    }
                  }
                  crossedThreshold = true
                }
                
                
                if !completedMatch && completionPercentage > 0.95 {
                  print("match over 95%, setting completedMatch to true, should only happen once***********")
                  completedMatch = true
                  self.setResponseHighlight(responseIdx: highestMatch.index!, count: dialogCount)
                  advance()
                }
                
                
              }
              // if self.currentNode.children[highestMatch.index!].dialog.characters.count/bestGuess.characters.count > 0.8 {
              // print("we have a match")
              //}
            }
            
            
          }

          if ((bestGuess.lowercased().range(of: "monkey")) != nil) {
              print("we have a match")
              inputNode.removeTap(onBus: 0)
              self.stopListeningLoop()
              self.playResponse()
          }
          // self.textView.text = bestGuess
          isFinal = result.isFinal
        }
          
        if error != nil || isFinal {
          print("okay error or isfinal")
          print(error)
          self.audioEngine.stop()
          inputNode.removeTap(onBus: 0)
          
          self.recognitionRequest = nil
          self.recognitionTask = nil
          
          self.recordButton.isEnabled = true
          self.recordButton.setTitle("Start Recording", for: [])
          self.recordingStatus.text = "Not recording"
        }
      }
    } 
    print("installing tap on inputnode")
    
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self.recognitionRequest?.append(buffer)
    }

    print("dope. now preparing/starting audioengine")
    audioEngine.prepare()
    try audioEngine.start()
  }
    
  private func stopListeningLoop() {
    self.recordingStopped = true
    self.recordingStatus.text = "Not recording"
    print("stopListeningLoop()")
    self.audioEngine.stop()
    self.recognitionRequest?.endAudio()
  }
  
  @objc private func delayedAction() {
    print("delay")
    print("proceed to next dialog")
    try! self.startListeningLoop()
  }
  
  private func playResponse() {
    // var timer = NSTimer()
    print("this is when the NPC responds")
    Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(delayedAction), userInfo: nil, repeats: false)
  }

  public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    print("setting recordButton back to 'start recording'")
    if available {
        recordButton.isEnabled = true
        recordButton.setTitle("Start Recording", for: [])
    } else {
        recordButton.isEnabled = false
        recordButton.setTitle("Recognition not available", for: .disabled)
    }
  }

  // view functions
  func addStoryView(node: Node) {
    print("stm: addStoryView, node id \(node.id)")
    let spaceBetween: CGFloat = 15.0
    let textView = StoryTextView(style: node.speaker)
    
    
    
    textView.text = node.text
    
    
    // set y position
    let storyTextViewList = storyScrollView.subviews.filter({ $0 is StoryTextView }) // filter for StoryTextViews
    // print("stm: storytextviewlist count \(storyTextViewList.count)")
    if storyTextViewList.count > 0 {
      if let prevStoryView = storyTextViewList.last as? StoryTextView { // get last one in list
        // print("stm: last storytextview is \(prevStoryView), frame y \(prevStoryView.frame.origin.y), height \(prevStoryView.frame.size.height)")
        let newY = prevStoryView.frame.origin.y + prevStoryView.frame.size.height + spaceBetween
        // print("stm: setting y to \(newY)")
        textView.frame.origin.y = newY
      }
    }
    
    storyScrollView.addSubview(textView)
    // set size
    textView.frame.size.width = storyScrollView.frame.size.width // set width to scrollview width to get proper height
    textView.sizeToFit() // size frame to match height
    textView.frame.size.width = storyScrollView.frame.size.width // set full width again
    
    // initially hidden to animate in
    textView.alpha = 0
    
    // set proper storyScrollView size
    storyScrollView.setContentViewSize()
    
    // scroll to bottom
    let bottomOffset = storyScrollView.contentSize.height - storyScrollView.bounds.size.height + storyScrollView.contentInset.bottom
    let bottomOffsetPt: CGPoint = CGPoint(x: 0, y: bottomOffset)
    
    if bottomOffset > 0 { // if we can scroll down
      
      UIView.animate(
        withDuration: 0.5,
        delay: 0.0,
        options: [.curveEaseInOut],
        animations: {
          self.storyScrollView.setContentOffset(bottomOffsetPt, animated: false)
        },
        completion: {_ in
          self.animateInStoryView(textView, node)
        })
      
    } else {
      self.animateInStoryView(textView, node)
    }
    
  }
  
  func animateInStoryView(_ view: StoryTextView, _ node: Node) {
    // animate in
    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        view.alpha = 1.0
      },
      completion: {_ in
        
        // after the new message shows in the story, either go to next or show responses
        if node.next != nil { // if node has a `next`
          
          // go to next node after a delay
          self.nextNode(node: node)
          
        } else if let responses = node.responses { // if responses, show them
          print("stm: current node \(self.currentNodeId), showing responses \(responses)")
          self.setResponses(responses)
        } else {
          self.restartButton.isHidden = false
          self.stopRecording()
        }
        
    })
  }
  
  func createAttrString(text: String) ->  NSMutableAttributedString {
    let attrString = NSMutableAttributedString(
      string: text,
      attributes: [
        NSFontAttributeName: UIFont(name: "Georgia", size: 16.0)!,
        NSForegroundColorAttributeName: UIColor(red:0.00, green:0.0, blue:0.0, alpha:0.65)
      ])
    
    return attrString
    
  }
  

  func setResponseHighlight(responseIdx: Int, count: Int) {
    print("set response highlight: idx \(responseIdx) count \(count)")
    let greenColor = UIColor(red:0.00, green:158/255.0, blue:84/255.0, alpha:1.0)
    let range = NSMakeRange(0, count)
    
    switch responseIdx {
      case 0:
        let newAttrString = NSMutableAttributedString(attributedString: response1.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: greenColor,
          range: range)
        
        response1.attributedText = newAttrString
      case 1:
        let newAttrString = NSMutableAttributedString(attributedString: response2.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: greenColor,
          range: range)
        response2.attributedText = newAttrString
      case 2:
        let newAttrString = NSMutableAttributedString(attributedString: response3.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: greenColor,
          range: range)
        response3.attributedText = newAttrString
      default:
        ()
    }

  }

  
  func setResponses(_ responses: [Int]) {
    
    let response1Node = nodes[responses[0]]!
    let response2Node = nodes[responses[1]]!
    let response3Node = nodes[responses[2]]!
    
    response1.attributedText = createAttrString(text: response1Node.text)
    response2.attributedText = createAttrString(text: response2Node.text)
    response3.attributedText = createAttrString(text: response3Node.text)
    
    response1.id = response1Node.id
    response2.id = response2Node.id
    response3.id = response3Node.id
    
    responseStack.isHidden = false
    
    // self.view.layoutIfNeeded()
    
    // animate responses in
    
    r1Translate = self.view.frame.size.height - response1.frame.origin.y
    r2Translate = self.view.frame.size.height - response2.frame.origin.y
    r3Translate = self.view.frame.size.height - response3.frame.origin.y

    response1.frame.origin.y += r1Translate!
    response2.frame.origin.y += r2Translate!
    response3.frame.origin.y += r3Translate!
 
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 0.0,
      options: [],
      animations: {
        
        self.response1.frame.origin.y -= self.r1Translate!
        
      }, completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 0.0,
      options: [],
      animations: {
        self.response2.frame.origin.y -= self.r2Translate!
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      usingSpringWithDamping: 0.8,
      initialSpringVelocity: 0.0,
      options: [],
      animations: {
        self.response3.frame.origin.y -= self.r3Translate!
      }, completion: nil)
    

  }
  
  func nextNode(node: Node) {
    print("stm: currently on node \(self.currentNodeId), going to next!")
    // currentNodeId starts from 1
    self.delay(seconds: 0.0) {
      if let nextNode = self.nodes[node.next!] {
        
        self.addStoryView(node: nextNode) // add storyView
        self.currentNodeId = node.next! // set current node id
        print("stm: current node id is \(self.currentNodeId)")
      }
      
    }
    
  }

  // MARK: Interface Builder actions
  
  /*
  @IBAction func recordButtonTapped() {
    if audioEngine.isRunning {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recordButton.isEnabled = false
        recordButton.setTitle("Stopping", for: .disabled)
    } else {
        try! startRecording()
        recordButton.setTitle("Stop recording", for: [])
    }
  }
  */
 
  
  
  @IBAction func recordButtonTapped() {
    print("recordButtonTapped")
    if audioEngine.isRunning {
      self.stopRecording()
    } else {
      try! startListeningLoop()
      recordButton.setTitle("Stop recording", for: [])
    }
  }
  
  func stopRecording() {
    // recordingStatus.text = "not recording"
    audioEngine.stop()
    recognitionRequest?.endAudio()
    recordButton.isEnabled = false
    recordButton.setTitle("Stopping", for: .disabled)
  }
  
  func responseSelectedByAudio(node: Node) {
    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        
        self.response1.frame.origin.y += self.r1Translate!
        
      }, completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y += self.r2Translate!
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y += self.r3Translate!
      },
      completion: {_ in
        
        self.responseStack.isHidden = true // hide responses
        
        // reset heights
        self.response1.frame.origin.y -= self.r1Translate!
        self.response2.frame.origin.y -= self.r2Translate!
        self.response3.frame.origin.y -= self.r3Translate!
        
        self.addStoryView(node: node)
        
    })
    
  }
  
  @IBAction func responseSelected(sender: AnyObject) {
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        
        self.response1.frame.origin.y += self.r1Translate!
        
      }, completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y += self.r2Translate!
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y += self.r3Translate!
      },
      completion: {_ in
        
        self.responseStack.isHidden = true // hide responses
        
        // reset heights
        self.response1.frame.origin.y -= self.r1Translate!
        self.response2.frame.origin.y -= self.r2Translate!
        self.response3.frame.origin.y -= self.r3Translate!
        
        print("stm: selected response # \(sender.tag!)")
        var responseId = 1
        switch(sender.tag) {
          case 1:
            responseId = self.response1.id
          case 2:
            responseId = self.response2.id
          case 3:
            responseId = self.response3.id
          default:
            ()
        }
        
        if let responseNode = self.nodes[responseId] {
          // add response to story
          self.addStoryView(node: responseNode)
        }
        
      })
    
  }
  
  @IBAction func restartButtonTapped() {
    print("restarting")
    resetAndInitializeStoryView()
    self.restartButton.isHidden = true
  }
  
  func resetAndInitializeStoryView() {
    // reset currentNodeId
    self.currentNodeId = 1
    
    // clear storyScrollView
    for subview in storyScrollView.subviews {
      subview.removeFromSuperview()
    }
    
    // add first node to view
    addStoryView(node: self.currentNode!)
    // if let node = self.nodes[self.currentNodeId] {
    //   addStoryView(node: node)
    // }
  }

  
  // A delay function
  func delay(seconds: Double, completion:()->()) {
    let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
    
    DispatchQueue.main.asyncAfter(deadline: popTime) {
      completion()
    }
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
        let responsesArr = responses.map { Int($0)! }
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

