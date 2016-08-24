//
//  StoryTextView.swift
//  SpeakToMe
//
//  Created by Andrew Hsu on 8/17/16.
//  Copyright © 2016 Henry Mason. All rights reserved.
//

import UIKit

class StoryTextView: UITextView {

  var id: Int = 1
  
  convenience init(text: String, speaker: String) {
    self.init(frame: CGRect.zero, textContainer: nil)
    
    let attrString = NSMutableAttributedString(
      string: text,
      attributes: [
        NSFontAttributeName: UIFont(name: "Georgia", size: 16.0)!,
        NSForegroundColorAttributeName: UIColor(red:0.00, green:0.00, blue:0.00, alpha:1.0)
      ])
    
    // standard attributes
    self.backgroundColor = UIColor.clear
    
    self.isEditable = false
    self.isSelectable = false
    self.isScrollEnabled = false
    
    // remove padding
    self.textContainerInset = UIEdgeInsets.zero
    self.textContainer.lineFragmentPadding = 0
    
    // debug: add border
    // self.layer.borderColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:0.25).cgColor
    // self.layer.borderWidth = 1.0
    
    let narratorPs: NSMutableParagraphStyle = NSMutableParagraphStyle()
    narratorPs.lineSpacing = 8
    narratorPs.headIndent = 15
    narratorPs.firstLineHeadIndent = 15
    
    let ps: NSMutableParagraphStyle = NSMutableParagraphStyle()
    ps.lineSpacing = 6
    ps.headIndent = 15
    
    switch speaker.lowercased() {
      case "narrator":
        attrString.addAttributes([
          NSParagraphStyleAttributeName: narratorPs,
          NSFontAttributeName: UIFont(name: "Georgia-Italic", size: 14.0)!
        ], range: NSMakeRange(0, attrString.length))
        
      case "albus": // user
        
        let name = NSMutableAttributedString(
          string: "YOU: ",
          attributes: [
            NSFontAttributeName: UIFont(name: "Georgia", size: 12.0)!
          ])
        name.append(attrString)
        attrString.replaceCharacters(in: NSMakeRange(0, attrString.length), with: name)
        
        attrString.addAttributes([
          NSForegroundColorAttributeName: UIColor(red:11/255.0, green:116/255.0, blue:57/255.0, alpha:1.0),
          NSParagraphStyleAttributeName: ps
          ], range: NSMakeRange(0, attrString.length))

      default: // case "ginny", "harry", "james", "rose", "scorpius", "lily", "sorting hat":
        let name = NSMutableAttributedString(
          string: "\(speaker.uppercased()): ",
          attributes: [
            NSFontAttributeName: UIFont(name: "Georgia", size: 12.0)!
          ])
        name.append(attrString)
        attrString.replaceCharacters(in: NSMakeRange(0, attrString.length), with: name)
        
        attrString.addAttributes([
          NSParagraphStyleAttributeName: ps
          ], range: NSMakeRange(0, attrString.length))
        
    }
    
    self.attributedText = attrString
    
  }
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: nil)
  }
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
  }
  
}

