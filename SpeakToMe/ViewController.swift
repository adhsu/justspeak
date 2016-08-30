import UIKit
import Speech
import AVFoundation

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
  
  // speech rec properties
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  
  // audio engine properties
  private let audioEngine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  private let musicNode = AVAudioPlayerNode()
  private let backgroundAudioNode = AVAudioPlayerNode()
  private var backgroundFaderNode: FaderNode?
  
  private var inputNode: AVAudioInputNode?
  private var mainMixer: AVAudioMixerNode?
  
  private var r1Translate : CGFloat = 0
  private var r2Translate : CGFloat = 0
  private var r3Translate : CGFloat = 0
  
  
  @IBOutlet var butanButton : UIButton!
  @IBOutlet var restartButton : UIButton!

  @IBOutlet var pauseButton : UIButton!
  @IBOutlet var playButton : UIButton!

  @IBOutlet var storyScrollView : UIScrollView!
  let storyScrollViewDefaultInsets = UIEdgeInsets(top: 20.0, left: 0, bottom: 20.0, right: 0)
  
  @IBOutlet var responseStack : UIStackView!
  @IBOutlet var response1 : ResponseTextView!
  @IBOutlet var response2 : ResponseTextView!
  @IBOutlet var response3 : ResponseTextView!
  
  @IBOutlet weak var recordingStatusLight: UIView!
  
  let rootNodeId: Int = 1
  var currentNodeId: Int = 1
  
  var nodes: [Int: Node] = [:] // dictionary of nodes, will construct in viewDidLoad
  var recordingStopped: Bool = true
  var audioStopped: Bool = true
  
  var paused: Bool = false
  let delayIfNoAudio: Double = 2.0
  let delayBeforeNewScene: Double = 1.0
  
  let greenColor: UIColor = UIColor(red:11/255.0, green:116/255.0, blue:57/255.0, alpha:1.0)
  let lightGreenColor: UIColor = UIColor(red:30/255.0, green:173/255.0, blue:109/255.0, alpha:1.0)
  let redColor: UIColor = UIColor(red:147/255.0, green:40/255.0, blue:40/255.0, alpha:1.0)
  let grayColor: UIColor = UIColor(red:0.00, green:0.0, blue:0.0, alpha:0.25)
  let fadeGrayColor: UIColor = UIColor(red:0.00, green:0.0, blue:0.0, alpha:0.65)

  
  // MARK: UIViewController
  
  override public func viewDidLoad() {
    // called once when controller loads view into memory, do things you have to do only once
    print("stm: viewDidLoad()")
    super.viewDidLoad()
    
    // set up audioSession
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
      try audioSession.setMode(AVAudioSessionModeDefault)
      try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
    } catch {
      print("audioSession properties weren't set because of an error.")
    }

    
    // start audioengine
    do {
      self.inputNode = audioEngine.inputNode
      
      self.mainMixer = audioEngine.mainMixerNode
      
      audioEngine.attach(self.playerNode)
      audioEngine.connect(self.playerNode, to: self.mainMixer!, format: mainMixer?.outputFormat(forBus: 0))
      
      audioEngine.attach(self.musicNode)
      audioEngine.connect(self.musicNode, to: self.mainMixer!, format: mainMixer?.outputFormat(forBus: 0))
      
      audioEngine.attach(self.backgroundAudioNode)
      audioEngine.connect(self.backgroundAudioNode, to: mainMixer!, format: mainMixer?.outputFormat(forBus: 0))
      backgroundAudioNode.volume = 0
      
      
      // start audioEngine
      print("start audioEngine")
      audioEngine.prepare()
      try audioEngine.start()
    } catch let err as NSError {
      print("couldn't start audioengine, error \(err)")
    }

    
    // Disable the record buttons until authorization has been granted.
    // recordButton.isEnabled = false
    
    // set up view padding
    let responsePadding: CGFloat = 16.0
    response1.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    response2.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    response3.textContainerInset = UIEdgeInsets(top: responsePadding, left: responsePadding, bottom: responsePadding, right: responsePadding)
    
    response1.textContainer.lineFragmentPadding = 0
    response2.textContainer.lineFragmentPadding = 0
    response3.textContainer.lineFragmentPadding = 0
    
    storyScrollView.contentInset = self.storyScrollViewDefaultInsets
    // storyScrollView.layer.borderColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:0.5).cgColor
    // storyScrollView.layer.borderWidth = 1.0
    // storyScrollView.backgroundColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:0.1)
    
    
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
    // print(nodes)
    
    
    


  }
  
  func goNext() {
    print("gonext")
    // audio plays on different thread, need to run this code on main thread
    DispatchQueue.main.async {
      
      if let node = self.nodes[self.currentNodeId] {
        
        if node.next != nil { // if node has a `next`
          self.nextNode(node: node)
        } else if let responses = node.responses { // if responses, show them
          print("stm: current node \(self.currentNodeId), showing responses \(responses)")
          self.setResponses(responses)
        } else {
          self.stopListeningLoop()
        }
      }
    }
  }
  
  func playAudio(node: Node) {
    
    self.audioStopped = false
    
    // play audio
    if let audioPath = Bundle.main.path(forResource: "audio/\(node.id).mp3", ofType: nil) {
      
      // print("playing audio \(node.id).mp3")
      let url = NSURL(fileURLWithPath: audioPath)
      
      do {
        let audioFile = try AVAudioFile(forReading: url as URL)
        
        playerNode.scheduleFile(audioFile, at: nil, completionHandler: {
          
          if !self.audioStopped {
            print("PLAYER NODE COMPLETION HANDLER HAHAHAHA")
            self.goNext()
          }
          
        })

        playerNode.play()
        
      } catch let err as NSError {
        print(err)
      }
      
    } else { // audio file not found
      // print("cannot find audio file for node \(node.id)")
      delay(seconds: self.delayIfNoAudio) {
        self.goNext()
      }
    }
    
  }
  
  override public func viewWillAppear(_ animated: Bool) {
    // called every time just before view is displayed/visible to user. always after viewDidLoad(). set up app state/view data here.
    // print("stm: viewWillAppear()")
    super.viewWillAppear(animated)
    
  }
  
  override public func viewDidLayoutSubviews() {
    // called after sizes (frames/bounds/etc) calculated. views already laid out by autolayout. handle anything dependent on bounds here.
    // print("stm: viewDidLayoutSubviews()")
    super.viewDidLayoutSubviews()
    
    // set up response status light radius
    recordingStatusLight.layer.cornerRadius = recordingStatusLight.frame.size.width/2
    recordingStatusLight.clipsToBounds = true
    
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    // view fully appears
    // print("stm: viewDidAppear()")
    
    resetAndInitializeStoryView(firstTime: true)
    
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
            ()
            // self.recordButton.isEnabled = true

          case .denied:
            ()
            // self.recordButton.isEnabled = false
            // self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

          case .restricted:
            ()
            // self.recordButton.isEnabled = false
            // self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

          case .notDetermined:
            ()
            // self.recordButton.isEnabled = false
            // self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
        }
      }
    }
  }
  

  // MARK: SFSpeechRecognizerDelegate

  private func matchScore(bestGuess: String, node: Node) -> Int {
    // Fuzzy match between transcription and children
    let bestGuess = bestGuess.characters.split{$0 == " "}.map(String.init) // split into array
    let realWordsInGuess = bestGuess.filter{ $0.characters.count >= 3 } // remove any word less than 3 characters long
    let count = realWordsInGuess.filter({ (node.text.lowercased().range(of: $0.lowercased()) != nil) }).count
    
    return count
  }
  
  
  private func startListeningLoop() throws {
    print("startListeningLoop()")
    self.recordingStopped = false
    var completedMatch = false
    var crossedThreshold = false
    var randomChatterIdx: Int = 0 // up to this index is random chatter in bestGuess

    // set up recognition request & audio input node
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
    recognitionRequest.shouldReportPartialResults = true

    // set up recognition task. cancel previous if running.
    if let recognitionTask = recognitionTask {
      print("cancelling recognitionTask")
      recognitionTask.cancel()
      self.recognitionTask = nil
    }

    // A recognition task represents a speech recognition session.
    // We keep a reference to the task so that it can be cancelled.
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      if !self.recordingStopped { // if we're recording
        var isFinal = false
        
        if let result = result, let currentNode = self.nodes[self.currentNodeId] {
          let bestGuess = result.bestTranscription.formattedString
          print("best guess: \(bestGuess)")
          
          var highestMatch: (index: Int?, matchCount: Int) = (nil, 0)
          
          // iterate through all responses and rank matchScores
          for (idx, responseId) in (currentNode.responses?.enumerated())! {
            let responseNode = self.nodes[responseId]!
            let matchCount = self.matchScore(bestGuess: bestGuess, node: responseNode) // matchScore is the total number of words we've matched
            
            if highestMatch.matchCount < matchCount, highestMatch.index != idx { // this new dialog option is the best match so far
              
              highestMatch = (idx, matchCount)
              print("new highest match idx \(idx)")
              self.clearResponseHighlights()
              // print("new highest match: \(responseNode.text)")
            }
          }
          if highestMatch.matchCount == 0 {
            print("no matches yet, bestGuess is \(bestGuess)")
            randomChatterIdx = bestGuess.characters.count-1 // if no match yet, assume everything is random chatter.

          } else if highestMatch.matchCount >= 2 {
            print("at least 2 matches. random chatter index is \(randomChatterIdx)")
            let responseNodeId = currentNode.responses?[highestMatch.index!]
            if let highlightedResponseNode: Node = self.nodes[responseNodeId!] {
              // print("new highlight: " + highlightedResponseNode.text)
              // if our transcript length is approaching the length of the best guess dialog option, move along the dialog
              let dialogCount: Int = highlightedResponseNode.text.characters.count
              let transcriptCount = bestGuess.characters.count - randomChatterIdx
              
              // print("dialog chars: \(dialogCount), transcript chars: \(transcriptCount)")
              self.setResponseHighlight(responseIdx: highestMatch.index!, count: min(dialogCount, transcriptCount))
              
              let completionPercentage: Float = Float(transcriptCount)/Float(dialogCount)
              if completionPercentage > 0.75 {
                print("we have a match of at least 75%.")
                
                if !crossedThreshold {
                  print("triggering delayed advance, should only happen once***********")
                  self.setResponseHighlight(responseIdx: highestMatch.index!, count: dialogCount)
                  self.delay(seconds: 0.25) {
                    if !completedMatch {
                      self.responseSelectedByAudio(node: highlightedResponseNode)
                    }
                  }
                  crossedThreshold = true
                }
                
                if !completedMatch && completionPercentage > 0.95 {
                  print("match over 95%, setting completedMatch to true, should only happen once***********")
                  completedMatch = true
                  self.setResponseHighlight(responseIdx: highestMatch.index!, count: dialogCount)
                  self.responseSelectedByAudio(node: highlightedResponseNode)
                }
              }
            }
          }
          isFinal = result.isFinal
        }
          
        if error != nil || isFinal {
          print("recognition Task: isFinal \(isFinal), error \(error)")
          
          // self.audioEngine.stop()
          self.recognitionRequest = nil
          self.recognitionTask = nil
          
          self.recordingStatusLight.backgroundColor = self.grayColor
        }
      }
    } 
    
    // set up inputNode, add it to recognition request. ok to do this after starting recognitionTask.
    print("install tap on inputNode, recording now")
    let recordingFormat = self.inputNode?.outputFormat(forBus: 0)
    self.inputNode?.removeTap(onBus: 0)
    self.inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self.recognitionRequest?.append(buffer)
    }
    recordingStatusLight.backgroundColor = self.lightGreenColor

  }
  
  func stopListeningLoop() {
    print("stopListeningLoop()")
    self.recordingStopped = true
    self.recordingStatusLight.backgroundColor = self.grayColor

    // self.audioEngine.stop()
    
    self.recognitionRequest?.endAudio()
    self.recognitionRequest = nil

    self.recognitionTask?.cancel()
    self.recognitionTask = nil

  }
  

  /*
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
  */

  func scrollViewToBottom(animated: Bool = true) {
    print("scrolling to bottom, animated \(animated)")
    let bottomOffset = storyScrollView.contentSize.height - storyScrollView.frame.size.height + storyScrollView.contentInset.bottom
    let bottomOffsetPt: CGPoint = CGPoint(x: 0, y: bottomOffset)

    if bottomOffset > 0 {
      self.storyScrollView.setContentOffset(bottomOffsetPt, animated: animated)
    }
    

  }
  
  func playMusic(_ filename: String) {
    print("playing music \(filename)")
    if let path = Bundle.main.path(forResource: "music/\(filename)", ofType: nil) {
      let url = NSURL(fileURLWithPath: path)
      do {
        let audioFile = try AVAudioFile(forReading: url as URL)
        musicNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        musicNode.play()
        
      } catch let err as NSError {
        print(err)
      }
    }
  }

  func playBackgroundLoop(_ filename: String) {
    print("playing background loop \(filename)")
    
    if self.backgroundAudioNode.isPlaying {
      print("bg audio node is playing, stop it ")
      self.backgroundAudioNode.stop()
    }
    
    if let path = Bundle.main.path(forResource: "music/\(filename)", ofType: nil) {
      let url = NSURL(fileURLWithPath: path)
      do {
        print("setting up new buffer \(filename), path \(path), url \(url)")
        let audioFile = try AVAudioFile(forReading: url as URL)
        let audioFormat = audioFile.processingFormat
        let audioFrameCount = UInt32(audioFile.length)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        try audioFile.read(into: audioFileBuffer)
        
        backgroundAudioNode.scheduleBuffer(audioFileBuffer, at: nil, options: .loops, completionHandler: nil)
        self.backgroundAudioNode.play()
        self.backgroundFaderNode = FaderNode(playerNode: backgroundAudioNode)
        self.backgroundFaderNode?.fade(fromVolume: 0, toVolume: 0.05)
        
        
      } catch let err as NSError {
        print(err)
      }
    }
  }
  
  func stopBackgroundLoop() {
    print("stop bg loop")
    self.backgroundFaderNode?.fadeOut() { finished in
      // self.backgroundAudioNode.stop()
    }
  }

  func processNode(node: Node) {
    print("stm: processNode, node id \(node.id)")

    switch node.speaker.lowercased() {

      case "music":
        self.playMusic(node.text)      
        self.goNext()
        return

      case "startmusicloop":
        self.playBackgroundLoop(node.text)
        self.goNext()
        return

      case "stopmusicloop":
        self.stopBackgroundLoop()
        self.goNext()
        return

      case "h1":

        if self.currentNodeId != self.rootNodeId {
          // if we're at a new scene, scroll all the way up
          UIView.animate(
            withDuration: 1.0,
            animations: {
              for subview in self.storyScrollView.subviews {
                subview.alpha = 0.0
              }
            },
            completion: {_ in
              // scroll to new screen
              self.setScrollBottomInset(amount: self.storyScrollView.frame.size.height, animated: false)
              // fade all storytextviews back in
              for subview in self.storyScrollView.subviews {
                subview.alpha = 1.0
              }

              self.delay(seconds: self.delayBeforeNewScene) {
                self.addStoryView(node: node)
              }
              
            })

          // sleep(5)
        } else {
          self.addStoryView(node: node)
        }

      default:
        self.addStoryView(node: node)

    }
  }
  
  func handleDoubleTap() {
    print("double tapped")
    self.playerNode.stop()
  }
  
  // view functions
  func addStoryView(node: Node) {
    print("stm: addStoryView, node id \(node.id)")
    
    let textView = StoryTextView(text: node.text, speaker: node.speaker, id: node.id)
    
    storyScrollView.addSubview(textView) 
    storyScrollView.setContentViewSize() // set proper storyScrollView size

    // check if scrollview has content inset
    let contentInsetExists = (self.storyScrollView.contentInset.bottom > self.storyScrollViewDefaultInsets.bottom)
    // print(self.storyScrollView.contentInset.bottom, self.storyScrollViewDefaultInsets.bottom)

    if contentInsetExists {
      // if it does, reduce the inset by height of new storytextview
      let newInset = self.storyScrollView.contentInset.bottom - textView.frame.size.height
      if newInset < self.storyScrollViewDefaultInsets.bottom {
        self.setScrollBottomInset(amount: self.storyScrollViewDefaultInsets.bottom, animated: true)
      } else {
        self.setScrollBottomInset(amount: newInset, animated: false)
      }
    } else {
      // otherwise, scroll to bottom
      self.scrollViewToBottom(animated: true)
    }
    
    // add tap gestures
    let doubleTap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap))
    doubleTap.numberOfTapsRequired = 2
    textView.addGestureRecognizer(doubleTap)

    // now play audio and fade in the storytextview
    self.playAudio(node: node)

    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        textView.alpha = 1.0
      },
      completion: nil)

  }
  

  func createAttrString(text: String) ->  NSMutableAttributedString {
    
    let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 5
    
    let attrString = NSMutableAttributedString(
      string: text,
      attributes: [
        NSFontAttributeName: UIFont(name: "Georgia", size: 16.0)!,
        NSForegroundColorAttributeName: self.fadeGrayColor,
        NSParagraphStyleAttributeName: paragraphStyle
      ])
    
    return attrString
    
  }
  
  func clearResponseHighlights() {
    print("clear response highlights")
    let newAttrString = NSMutableAttributedString(attributedString: response1.attributedText)
    print(response1.text.characters.count)
    
    newAttrString.addAttribute(
      NSForegroundColorAttributeName,
      value: self.fadeGrayColor,
      range: NSMakeRange(0, response1.text.characters.count))
    response1.attributedText = newAttrString
    
    let newAttrString2 = NSMutableAttributedString(attributedString: response2.attributedText)
    newAttrString2.addAttribute(
      NSForegroundColorAttributeName,
      value: self.fadeGrayColor,
      range: NSMakeRange(0, response2.text.characters.count))
    response2.attributedText = newAttrString2
    
    let newAttrString3 = NSMutableAttributedString(attributedString: response3.attributedText)
    newAttrString3.addAttribute(
      NSForegroundColorAttributeName,
      value: self.fadeGrayColor,
      range: NSMakeRange(0, response3.text.characters.count))
    response3.attributedText = newAttrString3
    
    
  }
  
  
  func setResponseHighlight(responseIdx: Int, count: Int) {
    // print("set response highlight: idx \(responseIdx) count \(count)")
    let range = NSMakeRange(0, count)
    
    switch responseIdx {
      case 0:
        let newAttrString = NSMutableAttributedString(attributedString: response1.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: self.lightGreenColor,
          range: range)
        
        response1.attributedText = newAttrString
      case 1:
        let newAttrString = NSMutableAttributedString(attributedString: response2.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: self.lightGreenColor,
          range: range)
        response2.attributedText = newAttrString
      case 2:
        let newAttrString = NSMutableAttributedString(attributedString: response3.attributedText)
        newAttrString.addAttribute(
          NSForegroundColorAttributeName,
          value: self.lightGreenColor,
          range: range)
        response3.attributedText = newAttrString
      default:
        ()
    }

  }

  

  func setResponses(_ responses: [Int]) {
    
    // start listening immediately, then animate responses in
    if self.recordingStopped {
      try! self.startListeningLoop()
    }
    


    let response1Node = nodes[responses[0]]!
    let response2Node = nodes[responses[1]]!
    let response3Node = nodes[responses[2]]!

    response1.attributedText = createAttrString(text: response1Node.text)
    response2.attributedText = createAttrString(text: response2Node.text)
    response3.attributedText = createAttrString(text: response3Node.text)
    self.view.layoutIfNeeded() // update height of responseStack after new text has been added
    response1.id = response1Node.id
    response2.id = response2Node.id
    response3.id = response3Node.id
    
    responseStack.isHidden = false
    recordingStatusLight.isHidden = false
    
    // initially hidden to animate in
    recordingStatusLight.alpha = 0
    
    
    // calculate distance between top of response view and bottom of frame
    
    r1Translate = self.view.frame.size.height - response1.frame.origin.y
    r2Translate = self.view.frame.size.height - response2.frame.origin.y
    r3Translate = self.view.frame.size.height - response3.frame.origin.y
    
    // move responses just offscreen with the translate values
    response1.frame.origin.y += r1Translate
    response2.frame.origin.y += r2Translate
    response3.frame.origin.y += r3Translate
    
    // move storyScrollView content up with contentInset
    self.setScrollBottomInset(amount: self.responseStack.frame.size.height + self.storyScrollViewDefaultInsets.bottom, animated: true)

    // animate responses back in
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        
        self.response1.frame.origin.y -= self.r1Translate
        self.recordingStatusLight.alpha = 1
      }, 
      completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.75,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y -= self.r2Translate
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 1,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y -= self.r3Translate
      }, 
      completion: nil)


  }
  
  func nextNode(node: Node) {
    // print("stm: currently on node \(self.currentNodeId), going to next!")
    if let nextNode = self.nodes[node.next!] {
      
      self.processNode(node: nextNode)
      self.currentNodeId = node.next! // set current node id
      // print("stm: current node id is \(self.currentNodeId)")
    }

  }

  
  func responseSelectedByAudio(node: Node) {

    self.currentNodeId = node.id // advance currentNode forward
    self.stopListeningLoop()

    

    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        self.recordingStatusLight.alpha = 0
        self.response1.frame.origin.y += self.r1Translate
        
      }, completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y += self.r2Translate
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y += self.r3Translate
      },
      completion: {_ in
        
        self.responseStack.isHidden = true // hide responses
        self.recordingStatusLight.isHidden = true
        
        // reset heights
        self.response1.frame.origin.y -= self.r1Translate
        self.response2.frame.origin.y -= self.r2Translate
        self.response3.frame.origin.y -= self.r3Translate
        
        self.processNode(node: node)
        
    })
    
  }
  
  @IBAction func responseSelected(sender: AnyObject) {
    
    self.stopListeningLoop()
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        self.recordingStatusLight.alpha = 0
        self.response1.frame.origin.y += self.r1Translate
        
      }, completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y += self.r2Translate
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y += self.r3Translate
      },
      completion: {_ in
        
        self.responseStack.isHidden = true // hide responses
        self.recordingStatusLight.isHidden = true
        
        // reset heights
        self.response1.frame.origin.y -= self.r1Translate
        self.response2.frame.origin.y -= self.r2Translate
        self.response3.frame.origin.y -= self.r3Translate
        
        // print("stm: selected response # \(sender.tag!)")
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
          self.currentNodeId = responseId // advance currentNode forward
          self.processNode(node: responseNode)
        }
        
      })
    
  }
  
  @IBAction func restartButtonTapped() {
    print("restarting")
    self.stopListeningLoop()
    self.resetAndInitializeStoryView()
    // self.restartButton.isHidden = true
  }
  
  @IBAction func pauseButtonTapped() {
    
    
    if !self.paused {
      print("pausing")
      self.paused = true
      self.playButton.isHidden = false
      self.pauseButton.isHidden = true
      
      // pause all audio player nodes
      self.playerNode.pause()
      self.musicNode.pause()
      self.backgroundAudioNode.pause()
      
      // stop listening
      if let node = self.nodes[self.currentNodeId], let responses = node.responses {
        print("node has responses, stop listening")
        self.stopListeningLoop()
      }
        
      

    } else {
      print("resuming")
      self.paused = false
      self.playButton.isHidden = true
      self.pauseButton.isHidden = false
      
      // resume all audio player nodes
      self.playerNode.play()
      self.musicNode.play()
      self.backgroundAudioNode.play()
      
      // resume listening
      if let node = self.nodes[self.currentNodeId], let responses = node.responses {
        print("node has responses, start listening")
        if self.recordingStopped {
          try! self.startListeningLoop()
        }
      }

    }
    
  }

  @IBAction func butanButtonTapped() {
    print("skip node")
    self.playerNode.stop()
  }
  
  func setScrollBottomInset(amount: CGFloat, animated: Bool = true) {
    print("setScrollBottomInset \(amount), animated \(animated)")
    
    if animated {

      self.view.layoutIfNeeded()
      UIView.animate(
        withDuration: 0.5,
        delay: 0.0,
        options: [.curveEaseInOut],
        animations: {
          // add contentInset on bottom
          self.storyScrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0, bottom: amount, right: 0)
          
          // scroll it to bottom via contentOffset
          self.scrollViewToBottom(animated: false)
          
          self.view.layoutIfNeeded()
          
        }, completion: nil)

    } else {
      // add content inset on bottom
      self.storyScrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0, bottom: amount, right: 0)
      
      // scroll it to bottom
      self.scrollViewToBottom(animated: false)
    }
    
  }
  
  func resetAndInitializeStoryView(firstTime: Bool = false) {
    print("resetAndInitializeStoryView")
    
    // reset pause state    
    self.paused = false
    self.playButton.isHidden = true
    self.pauseButton.isHidden = false

    // stop audio, music, background loops
    self.audioStopped = true
    self.playerNode.stop()
    self.musicNode.stop()
    self.stopBackgroundLoop()


    // clear storyScrollView
    if !firstTime {
      for subview in storyScrollView.subviews {
        subview.removeFromSuperview()
      }
      // reset content inset
      self.storyScrollView.contentInset = self.storyScrollViewDefaultInsets

    }

    // set responses off screen to animate onscreen in viewDidAppear()
    responseStack.isHidden = true
    recordingStatusLight.isHidden = true
    recordingStatusLight.backgroundColor = self.grayColor
    
    // reset currentNodeId
    self.currentNodeId = self.rootNodeId
    
    // add first node to view
    if let node = self.nodes[self.currentNodeId] {
      self.processNode(node: node)
    }
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

