import UIKit
import Speech
import AVFoundation


public class ViewController: UIViewController, SFSpeechRecognizerDelegate, UIScrollViewDelegate {
  
  let story = Story.sharedInstance
  
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
  var audioCompletionQueue: [UInt64: Completion] = [:]
  
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
    
  var recordingStopped: Bool = true
  var showingResponses: Bool = false
  var currentScrollOffset: CGFloat = 0
  var originalResponseStackY: CGFloat = 0
  
  
  var paused: Bool = false
  let delayIfNoAudio: Double = 0.4
  let delayTitle: Double = 1.0
  let delayBeforeNewScene: Double = 1.0
  
  let greenColor: UIColor = UIColor(red:11/255.0, green:116/255.0, blue:57/255.0, alpha:1.0)
  let lightGreenColor: UIColor = UIColor(red:30/255.0, green:173/255.0, blue:109/255.0, alpha:1.0)
  let redColor: UIColor = UIColor(red:147/255.0, green:40/255.0, blue:40/255.0, alpha:1.0)
  let grayColor: UIColor = UIColor(red:0.00, green:0.0, blue:0.0, alpha:0.25)
  let fadeGrayColor: UIColor = UIColor(red:0.00, green:0.0, blue:0.0, alpha:0.65)

  var markupIndices: [Int] = []
  
  // MARK: UIViewController
  
  override public func viewDidLoad() {
    // called once when controller loads view into memory, do things you have to do only once
    print("viewDidLoad(), current scene is \(self.story.currentSceneIndex+1)")
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

      if let path = Bundle.main.path(forResource: "10.mp3", ofType: nil) {
        let url = NSURL(fileURLWithPath: path)
        do {
          let audioFile = try AVAudioFile(forReading: url as URL)
          let audioFormat = audioFile.processingFormat
          audioEngine.connect(self.playerNode, to: self.mainMixer!, format: audioFormat)

        } catch let err as NSError {
          print(err)
        }
      }
      
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
    
    
    
    
  }
  
  override public func viewWillAppear(_ animated: Bool) {
    // called every time just before view is displayed/visible to user. always after viewDidLoad(). set up app state/view data here.
    // print("viewWillAppear()")
    super.viewWillAppear(animated)
    
  }
  
  override public func viewDidLayoutSubviews() {
    // called after sizes (frames/bounds/etc) calculated. views already laid out by autolayout. handle anything dependent on bounds here.
    // print("viewDidLayoutSubviews()")
    super.viewDidLayoutSubviews()
    
    // set up response status light radius
    recordingStatusLight.layer.cornerRadius = recordingStatusLight.frame.size.width/2
    recordingStatusLight.clipsToBounds = true
    
  }
  
  override public func viewDidAppear(_ animated: Bool) {
    // view fully appears
    // print("viewDidAppear()")
    
    resetAndInitializeStoryView(firstTime: true)
    
    // speech stuff
    speechRecognizer.delegate = self
    storyScrollView.delegate = self
    
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
  

  // MARK: SPEECH RECOGNITION METHODS

  private func matchScore(bestGuess: String, node: Node) -> Int {
    // Fuzzy match between transcription and children
    let bestGuess = bestGuess.characters.split{$0 == " "}.map(String.init) // split into array
    let realWordsInGuess = bestGuess.filter{ $0.characters.count >= 3 } // remove any word less than 3 characters long
    
    // look at guess, filter FOR guess words that are in the transcript.
    let count = realWordsInGuess.filter({ (node.text.lowercased().range(of: $0.lowercased()) != nil) }).count
    
    return count
  }
  
  func createMarkupIndices(bestGuess: String, node: Node) {
    
    let bestGuess = bestGuess.characters.split{$0 == " "}.map(String.init) // split into array
    let realWordsInGuess = bestGuess.filter{ $0.characters.count >= 3 } // remove any word less than 3 characters long
    
    var shouldSave: [Int] = []
    for (i, nodeWord) in node.text.lowercased().components(separatedBy: " ").enumerated() {
      
      if nodeWord.characters.count > 4 {
        // check if it's in realWordsInGuess
        let nodeWordCount = realWordsInGuess.filter { $0.range(of: nodeWord) != nil }.count
        
        if nodeWordCount == 0 {
          print("word large and not in guess: \(nodeWord). index \(i)")
          shouldSave.append(i)
        }
      }
    }
    print("shouldSave is \(shouldSave)")
    self.markupIndices = shouldSave
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
        
        if let result = result, let currentNode = self.story.nodes[self.story.currentNodeId] {
          let bestGuess = result.bestTranscription.formattedString
          print("best guess: \(bestGuess)")
          
          var highestMatch: (index: Int?, matchCount: Int) = (nil, 0)
          
          // iterate through all responses and rank matchScores
          for (idx, responseId) in (currentNode.responses?.enumerated())! {
            let responseNode = self.story.nodes[responseId]!
            let matchCount = self.matchScore(bestGuess: bestGuess, node: responseNode) // matchScore is the total number of words we've matched
            
            
            
            if highestMatch.matchCount < matchCount, highestMatch.index != idx { // this new dialog option is the best match so far
              
              highestMatch = (idx, matchCount)
              print("new highest match idx \(idx)")
              self.clearResponseHighlights()
              
              self.createMarkupIndices(bestGuess: bestGuess, node: responseNode)
              
              // print("new highest match: \(responseNode.text)")
            }
          }
          if highestMatch.matchCount == 0 {
            print("no matches yet, bestGuess is \(bestGuess)")
            randomChatterIdx = bestGuess.characters.count-1 // if no match yet, assume everything is random chatter.

          } else if highestMatch.matchCount >= 2 {
            print("at least 2 matches. random chatter index is \(randomChatterIdx)")
            let responseNodeId = currentNode.responses?[highestMatch.index!]
            if let highlightedResponseNode: Node = self.story.nodes[responseNodeId!] {
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


  // MARK: scene controller and segue methods

  func showSummaryScreen() {
    
    self.stopListeningLoop()
    
    self.playerNode.stop()
    self.musicNode.stop()
    self.stopBackgroundLoop()

    
    self.performSegue(withIdentifier: "showSummarySegue", sender: nil)

  }

  @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
    print("unwinding")
    self.clearStoryScrollView()
    
  }
  
  override public func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
    
    if segue.identifier == "showSummarySegue" {
      let summaryViewController = segue.destination as! SummaryViewController
      summaryViewController.score = Int(50 + arc4random_uniform(50)) // generate random int between 50 and 100
      
    }
  }
  

  // MARK: story methods
  
  func clearStoryScrollView() {
    print("clearing storyScrollView")
    for subview in self.storyScrollView.subviews {
      subview.removeFromSuperview()
    }
    // reset content inset
    self.storyScrollView.contentInset = self.storyScrollViewDefaultInsets

  }

  func resetAndInitializeStoryView(firstTime: Bool = false) {
    print("resetAndInitializeStoryView")
    
    // reset pause state    
    self.paused = false
    self.playButton.isHidden = true
    self.pauseButton.isHidden = false

    // stop audio, music, background loops

    self.audioCompletionQueue = [:]
    self.playerNode.stop()
    self.musicNode.stop()
    self.stopBackgroundLoop()


    // clear storyScrollView
    if !firstTime {
      self.clearStoryScrollView()
    }

    // set responses off screen to animate onscreen in viewDidAppear()
    responseStack.isHidden = true
    recordingStatusLight.isHidden = true
    recordingStatusLight.backgroundColor = self.grayColor
    
    // reset currentNodeId
    self.story.currentNodeId = self.story.currentSceneStartingId
    
    // add first node to view
    if let node = self.story.nodes[self.story.currentNodeId] {
      self.processNode(node: node)
    }
  }

  
  // MARK: scroll methods

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

  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // print("scrollViewDidScroll, offset is \(scrollView.contentOffset)")
    if self.showingResponses {
      // print("self.currentScrollOffset \(self.currentScrollOffset)")
      // print(scrollView.contentOffset.y - self.currentScrollOffset)
      let offset = scrollView.contentOffset.y - self.currentScrollOffset
      
      if offset < 0 {
        // print("offset is \(offset)")
        // print("responsestack y is \(self.responseStack.frame.origin.y)")
        
        self.responseStack.frame.origin.y = self.originalResponseStackY - offset
        self.recordingStatusLight.frame.origin.y = self.originalResponseStackY - (16+12) - offset // light is 16px above responseStack and 12px high
        // self.view.layoutIfNeeded()
      } else {
        self.responseStack.frame.origin.y = self.originalResponseStackY
        self.recordingStatusLight.frame.origin.y = self.originalResponseStackY - (16+12) // light is 16px above responseStack and 12px high
      } 
    }
  }

  func scrollViewToBottom(animated: Bool = true) {
    // print("scrolling to bottom, animated \(animated)")
    let bottomOffset = storyScrollView.contentSize.height - storyScrollView.frame.size.height + storyScrollView.contentInset.bottom
    let bottomOffsetPt: CGPoint = CGPoint(x: 0, y: bottomOffset)
    
    if bottomOffset > 0 {
      self.currentScrollOffset = bottomOffset
      self.storyScrollView.setContentOffset(bottomOffsetPt, animated: animated)
    }
    
  }
  
  // MARK: audio/music methods

  func playAudio(node: Node, completionHandler: () -> Void = {}) {
    
    // play audio
    if let path = Bundle.main.path(forResource: "\(node.id).mp3", ofType: nil) {
      
      let url = NSURL(fileURLWithPath: path)
      do {
        let audioFile = try AVAudioFile(forReading: url as URL)
        let audioFormat = audioFile.processingFormat

        let audioFrameCount = UInt32(audioFile.length)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        try audioFile.read(into: audioFileBuffer)
        
        self.playerNode.scheduleBuffer(audioFileBuffer, at: nil, completionHandler: {
          // audio plays on different thread, need to run this code on main thread
          DispatchQueue.main.async(execute: completionHandler)
        })
        
        self.playerNode.play()
      } catch let err as NSError {
        print(err)
      }
    } else { // audio file not found
      // print("cannot find audio file for node \(node.id)")
      
      switch node.speaker.lowercased() {
        case "h1", "h2", "picture":
          delay(seconds: self.delayTitle) {
            self.goNext()
          }
        default:
          
          delay(seconds: self.delayIfNoAudio) {
            self.goNext()
          }
      }
    }
  }

  func playMusic(_ filename: String, completionHandler: () -> Void = {}) {
    print("playing music \(filename)")
    if let path = Bundle.main.path(forResource: "\(filename)", ofType: nil) {
      let url = NSURL(fileURLWithPath: path)
      do {
        let audioFile = try AVAudioFile(forReading: url as URL)
        musicNode.scheduleFile(audioFile, at: nil, completionHandler: completionHandler)
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
        // print("setting up new buffer \(filename), path \(path), url \(url)")
        let audioFile = try AVAudioFile(forReading: url as URL)
        let audioFormat = audioFile.processingFormat
        let audioFrameCount = UInt32(audioFile.length)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        try audioFile.read(into: audioFileBuffer)
        
        self.backgroundAudioNode.scheduleBuffer(audioFileBuffer, at: nil, options: .loops, completionHandler: nil)
        self.backgroundAudioNode.play()
        self.backgroundFaderNode = FaderNode(playerNode: backgroundAudioNode)
        self.backgroundFaderNode?.fade(fromVolume: 0, toVolume: 0.1)
        
        
      } catch let err as NSError {
        print(err)
      }
    }
  }
  
  func stopBackgroundLoop() {
    // print("stop bg loop")
    self.backgroundFaderNode?.fadeOut() { finished in
      // self.backgroundAudioNode.stop()
    }
  }


  // MARK: Node processing methods

  func processNode(node: Node) {
    // print("processNode, node id \(node.id)")

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

      default:
        self.addStoryView(node: node)

    }
  }
  
  func goNext() {
    if let node = self.story.nodes[self.story.currentNodeId] {
      
      if node.next != nil { // if node has a `next`
        
        if let nextNode = self.story.nodes[node.next!] {
          self.processNode(node: nextNode)
          self.story.currentNodeId = node.next! // set current node id
          // print("current node id is \(self.currentNodeId)")
        }

      } else if let responses = node.responses { // if responses, show them

        print("current node \(self.story.currentNodeId), showing responses \(responses)")
        self.setResponses(responses)
        
      } else { // end of scene
        self.delay(seconds: 2.0) {
          self.showSummaryScreen()

        }
        
      }
    }
    
  }
  
  // view functions
  func addStoryView(node: Node) {
    print("addStoryView, node id \(node.id)")
    
    let textView = StoryTextView(text: node.text, speaker: node.speaker, id: node.id, markupIndices: self.markupIndices)
    
    self.markupIndices = []
    
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
    
    let timestamp = UInt64(floor(NSDate().timeIntervalSince1970*1000))
    let audioCompletion = Completion(timestamp)
    self.audioCompletionQueue[timestamp] = audioCompletion
    
    self.playAudio(node: node, completionHandler: {
      print("play audio completion, timestamp \(timestamp)")
      if let completion = self.audioCompletionQueue[timestamp] {
        print("found it")
        
        if !completion.cancelled {
          self.goNext()
          completion.cancelled = true
        } else {
          print("completion \(timestamp) was found but cancelled")
        }
        
      } else {
        print("cannot find \(timestamp) in the queue")
      }
      
    })

    UIView.animate(
      withDuration: 0.5,
      delay: 0.0,
      options: [.curveEaseInOut],
      animations: {
        textView.alpha = 1.0
      },
      completion: nil)

  }

  func handleDoubleTap() {
    print("double tapped")
    self.playerNode.stop()
  }
  
  
  // MARK: response-related methods

  func setResponses(_ responses: [Int]) {
    
    self.showingResponses = true
    
    let response1Node = self.story.nodes[responses[0]]!
    let response2Node = self.story.nodes[responses[1]]!
    let response3Node = self.story.nodes[responses[2]]!

    response1.attributedText = createAttrString(text: response1Node.text)
    response2.attributedText = createAttrString(text: response2Node.text)
    response3.attributedText = createAttrString(text: response3Node.text)
    self.view.layoutIfNeeded() // update height of responseStack after new text has been added
    self.originalResponseStackY = self.responseStack.frame.origin.y
    print("response stack y is \(self.originalResponseStackY)")
    
    
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
      delay: 0,
      options: [.curveEaseInOut],
      animations: {
        
        self.response1.frame.origin.y -= self.r1Translate
        self.recordingStatusLight.alpha = 1
      }, 
      completion: nil)
    
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.25,
      options: [.curveEaseInOut],
      animations: {
        self.response2.frame.origin.y -= self.r2Translate
      }, completion: nil)
    
    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      options: [.curveEaseInOut],
      animations: {
        self.response3.frame.origin.y -= self.r3Translate
      }, 
      completion: {_ in
        if self.recordingStopped {
          try! self.startListeningLoop()
        }
      })


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

  func responseSelectedByAudio(node: Node) {
    self.showingResponses = false
    self.story.currentNodeId = node.id // advance currentNode forward
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
    self.showingResponses = false
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
        
        // print("selected response # \(sender.tag!)")
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


        if let responseNode = self.story.nodes[responseId] {
          // add response to story
          self.story.currentNodeId = responseId // advance currentNode forward
          self.processNode(node: responseNode)
        }
        
      })
    
  }
  

  // MARK: IBAction methods for interface

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
      if let node = self.story.nodes[self.story.currentNodeId] {
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
      if let node = self.story.nodes[self.story.currentNodeId], let responses = node.responses {
        print("node has responses, start listening")
        if self.recordingStopped {
          try! self.startListeningLoop()
        }
      }

    }
    
  }

  @IBAction func butanButtonTapped() {
    print("butan tapped")
    performSegue(withIdentifier: "showSummarySegue", sender: nil)

  }
  
  
  // MARK: utility methods

  func delay(seconds: Double, completion:()->()) {
    let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
    
    DispatchQueue.main.asyncAfter(deadline: popTime) {
      completion()
    }
  }

  
}

