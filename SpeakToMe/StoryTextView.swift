//
//  StoryTextView.swift
//  SpeakToMe
//
//  Created by Andrew Hsu on 8/17/16.
//  Copyright © 2016 Henry Mason. All rights reserved.
//

import UIKit

class StoryTextView: UITextView {

  var id: Int?
  var speaker: String?
  
  convenience init(text: String, speaker: String, id: Int) {
    self.init(frame: CGRect.zero, textContainer: nil)
    
    self.id = id
    self.speaker = speaker
    
    // standard attributes
    self.backgroundColor = UIColor.clear
    
    self.isEditable = false
    self.isSelectable = false
    self.isScrollEnabled = false
    self.showsVerticalScrollIndicator = false
    self.showsHorizontalScrollIndicator = false
    // remove padding
    self.textContainerInset = UIEdgeInsets.zero
    self.textContainer.lineFragmentPadding = 0
    
    // debug: add border
    // self.layer.borderColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:0.1).cgColor
    // self.layer.borderWidth = 1.0
    
    
    // IMAGE, return here
    if speaker.lowercased() == "picture" {
      return
    }
    
    // TEXT: construct attributed string
    let attrString = NSMutableAttributedString(
      string: text,
      attributes: [
        NSFontAttributeName: UIFont(name: "Georgia", size: 16.0)!,
        NSForegroundColorAttributeName: UIColor(red:0.00, green:0.00, blue:0.00, alpha:1.0)
      ])
    
    let headerPs: NSMutableParagraphStyle = NSMutableParagraphStyle()
    headerPs.alignment = NSTextAlignment.center
    
    let narratorPs: NSMutableParagraphStyle = NSMutableParagraphStyle()
    narratorPs.lineSpacing = 8
    narratorPs.headIndent = 20
    narratorPs.firstLineHeadIndent = 20
    
    let ps: NSMutableParagraphStyle = NSMutableParagraphStyle()
    ps.lineSpacing = 6
    ps.headIndent = 20
    
    switch speaker.lowercased() {
      
      
      case "h1":
        
        attrString.addAttributes([
          NSParagraphStyleAttributeName: headerPs,
          NSFontAttributeName: UIFont(name: "Georgia", size: 22.0)!
          ], range: NSMakeRange(0, attrString.length))
      
        self.textContainerInset = UIEdgeInsets(top: 40.0, left: 0, bottom: 40.0, right: 0)
      
      

      case "h2":
        attrString.addAttributes([
          NSParagraphStyleAttributeName: headerPs,
          NSFontAttributeName: UIFont(name: "Georgia", size: 16.0)!
          ], range: NSMakeRange(0, attrString.length))
        
        self.textContainerInset = UIEdgeInsets(top: 90.0, left: 0, bottom: 80.0, right: 0)
      
      
      case "narrator":
        attrString.addAttributes([
          NSParagraphStyleAttributeName: narratorPs,
          NSFontAttributeName: UIFont(name: "Georgia-Italic", size: 14.0)!
        ], range: NSMakeRange(0, attrString.length))
        self.textContainerInset = UIEdgeInsets(top: 10.0, left: 0, bottom: 10.0, right: 0)
        
      case "albus": // user
        addAuthorName(name: "you", attrString: attrString)
        attrString.addAttributes([
          NSForegroundColorAttributeName: UIColor(red:30/255.0, green:173/255.0, blue:109/255.0, alpha:1.0),
          NSParagraphStyleAttributeName: ps
          ], range: NSMakeRange(0, attrString.length))
        self.textContainerInset = UIEdgeInsets(top: 10.0, left: 0, bottom: 10.0, right: 0)

      default: // case "ginny", "harry", "james", "rose", "scorpius", "lily", "sorting hat":
        addAuthorName(name: speaker, attrString: attrString)
        attrString.addAttributes([
          NSParagraphStyleAttributeName: ps
          ], range: NSMakeRange(0, attrString.length))
        self.textContainerInset = UIEdgeInsets(top: 10.0, left: 0, bottom: 10.0, right: 0)
    }
    
    self.attributedText = attrString
    
    
    
  }
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: nil)
  }
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
  }
  
  // override this uiview method that detects when this StoryTextView is added as a subview to the scrollview
  // IMPORTANT: this also runs when this StoryTextView is removed from the superview e.g. when resetting the scrollview
  override func willMove(toSuperview newSuperview: UIView?) {
    
    
    // let spaceBetween: CGFloat = 20.0
    
    if newSuperview == nil {
      print("superview is nil, not doing anything in willMove")
      return
    }
    
    // print("moved to superview \(newSuperview)")
    
    // set y position
    let storyTextViewList = newSuperview?.subviews.filter({ $0 is StoryTextView }) // filter for StoryTextViews
    // print("stm: storytextviewlist count \(storyTextViewList.count)")
    if storyTextViewList?.count > 0 {
      if let prevStoryView = storyTextViewList?.last as? StoryTextView { // get last one in list
        // print("stm: last storytextview is \(prevStoryView), frame y \(prevStoryView.frame.origin.y), height \(prevStoryView.frame.size.height)")
        let newY = prevStoryView.frame.origin.y + prevStoryView.frame.size.height
        // print("stm: setting y to \(newY)")
        self.frame.origin.y = newY
      }
    }
    
    // set size
    self.frame.size.width = (newSuperview?.frame.size.width)! // set width to scrollview width to get proper height
    self.sizeToFit() // size frame to match height
    self.frame.size.width = (newSuperview?.frame.size.width)! // set full width again
    
    // initially hidden to animate in
    self.alpha = 0
    
    if self.speaker!.lowercased() == "picture" {
      
      let image = UIImage(named: "title-1.png")
      let imageView = UIImageView(image: image)
      imageView.contentMode = .scaleAspectFit
      self.addSubview(imageView)
      
      // set imageView size
      let scaleFactor = imageView.frame.size.width/self.frame.size.width
      imageView.frame.size.width /= scaleFactor
      imageView.frame.size.height /= scaleFactor
      
      // set frame size with padding
      let topPadding: CGFloat = 20
      let bottomPadding: CGFloat = 80
      
      self.frame.size.width = imageView.frame.size.width
      self.frame.size.height = imageView.frame.size.height + topPadding + bottomPadding
      imageView.frame.origin.y = topPadding
      
      
    }
    
    // if h2, add the broomstick after h2 frame has been sized
    if self.speaker!.lowercased() == "h2" {
      let image = UIImage(named: "broomstick.png")
      let imageView = UIImageView(image: image)
      imageView.contentMode = .scaleAspectFit
      self.addSubview(imageView)
      
      imageView.frame.size.width = 71
      imageView.frame.origin.x = self.frame.size.width/2 - imageView.frame.size.width/2
      imageView.frame.origin.y = 0
      
    }
  }
  
  func addAuthorName(name: String, attrString: NSMutableAttributedString) {
    let name = NSMutableAttributedString(
      string: "\(name.uppercased()): ",
      attributes: [
        NSFontAttributeName: UIFont(name: "Georgia", size: 12.0)!
      ])
    name.append(attrString)
    attrString.replaceCharacters(in: NSMakeRange(0, attrString.length), with: name)
    
  }
  
}

