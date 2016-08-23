//
//  ResponseTextView.swift
//  SpeakToMe
//
//  Created by Andrew Hsu on 8/18/16.
//  Copyright © 2016 Henry Mason. All rights reserved.
//

import UIKit

class ResponseTextView: UITextView {
  
  var id: Int = 1 // stores id of the response node
  
  convenience init(style: String) {
    self.init(frame: CGRect.zero, textContainer: nil)
    
  }
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: nil)
  }
  
  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)!
  }
  
}
