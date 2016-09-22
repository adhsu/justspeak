import UIKit

class SummaryViewController: UIViewController {
  
  // PROPERTIES
  let story = Story.sharedInstance

  var score: Int?
  @IBOutlet var scoreLabel : UILabel!
  @IBOutlet var scoreBadge : UIImageView!
  @IBOutlet var nextButton : UIButton!
  
  // METHODS
  override func viewDidLoad() {
    
    super.viewDidLoad()
        
    if let score = self.score {
      self.scoreLabel.text = String(score)      
    }
    
    // add radius to "practice these" button
    nextButton.layer.cornerRadius = 25
    
  }

  override public func viewDidAppear(_ animated: Bool) {
    // animate in score badge
    self.scoreBadge.transform = CGAffineTransform(scaleX: 0, y: 0)
    self.scoreBadge.isHidden = false

    UIView.animate(
      withDuration: 0.5,
      delay: 0.5,
      usingSpringWithDamping: 0.5,
      initialSpringVelocity: 0.0,
      options: [.curveEaseInOut],
      animations: {
        self.scoreBadge.transform = CGAffineTransform(scaleX: 1, y: 1)
      }, completion: nil)

  }

  override func didReceiveMemoryWarning() {
      super.didReceiveMemoryWarning()
      // Dispose of any resources that can be recreated.
  }

  override public func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
    
    if segue.identifier == "nextSceneSegue" {
      // let viewController = segue.destination as! ViewController

      self.story.currentSceneIndex += 1
      print("next scene segue")

    }
  }

  @IBAction func nextButtonTapped() {
    print("next tapped")
    
  }

}
