//
//  StoryTextView.swift
//  SpeakToMe
//
//  Created by Andrew Hsu on 8/17/16.
//  Copyright © 2016 Henry Mason. All rights reserved.
//

import UIKit

class StoryTextView: UITextView {

  var style: String = "hi"
  var id: Int = 1
  
  convenience init(style: String) {
    self.init(frame: CGRect.zero, textContainer: nil)
    self.style = style
    
    // standard attributes
    self.font = UIFont(name: "Georgia", size: 16.0)
    self.textColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:1.0)
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
    
    switch self.style {
      case "narrator":
        self.font = UIFont(name: "Georgia-Italic", size: 16.0)
      case "rrh":
        self.textColor = UIColor(red:0.58, green:0.16, blue:0.16, alpha:1.0) // #932828, dark red
      case "response":
        self.textColor = UIColor(red:0.00, green:0.00, blue:0.00, alpha:1.0)
      
      default:
        () // do nothing
    }
  }
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: nil)
  }
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
  }
  
}

