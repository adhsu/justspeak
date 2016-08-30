import Foundation
import AVFoundation

let FaderNode_defaultFadeDurationSeconds = 1.0
let FaderNode_defaultVelocity = 2.0

public class FaderNode: NSObject {
  let playerNode: AVAudioPlayerNode
  private var timer: Timer?
  
  // The higher the number - the higher the quality of fade
  // and it will consume more CPU.
  var volumeAlterationsPerSecond = 15.0
  
  private var fadeDurationSeconds = FaderNode_defaultFadeDurationSeconds
  private var fadeVelocity = FaderNode_defaultVelocity
  
  private var fromVolume = 0.0
  private var toVolume = 0.0
  
  private var currentStep = 0
  
  private var onFinished: ((Bool)->())? = nil
  
  init(playerNode: AVAudioPlayerNode) {
    self.playerNode = playerNode
  }
  
  deinit {
    callOnFinished(false)
    stop()
  }
  
  private var fadeIn: Bool {
    return fromVolume < toVolume
  }
  
  func fadeIn(duration: Double = FaderNode_defaultFadeDurationSeconds,
              velocity: Double = FaderNode_defaultVelocity, onFinished: ((Bool)->())? = nil) {
    fade(
      fromVolume: Double(
        playerNode.volume), toVolume: 1,
      duration: duration, velocity: velocity, onFinished: onFinished)
  }
  
  func fadeOut(duration: Double = FaderNode_defaultFadeDurationSeconds,
               velocity: Double = FaderNode_defaultVelocity, onFinished: ((Bool)->())? = nil) {
    
    fade(
      fromVolume: Double(
        playerNode.volume), toVolume: 0,
      duration: duration, velocity: velocity, onFinished: onFinished)
  }
  
  func fade(fromVolume: Double, toVolume: Double,
            duration: Double = FaderNode_defaultFadeDurationSeconds,
            velocity: Double = FaderNode_defaultVelocity, onFinished: ((Bool)->())? = nil) {
    
    self.fromVolume = FaderNode.makeSureValueIsBetween0and1(fromVolume)
    self.toVolume = FaderNode.makeSureValueIsBetween0and1(toVolume)
    self.fadeDurationSeconds = duration
    self.fadeVelocity = velocity
    
    callOnFinished(false)
    self.onFinished = onFinished
    
    
    print("volume to \( Float(self.fromVolume) ) (fade)")
    playerNode.volume = Float(self.fromVolume)
    
    if self.fromVolume == self.toVolume {
      callOnFinished(true)
      return
    }
    
    startTimer()
  }
  
  // Stop fading. Does not stop the sound.
  func stop() {
    stopTimer()
  }
  
  private func callOnFinished(_ finished: Bool) {
    onFinished?(finished)
    onFinished = nil
  }
  
  private func startTimer() {
    stopTimer()
    currentStep = 0
    
    timer = Timer.scheduledTimer(timeInterval: 1 / volumeAlterationsPerSecond, target: self,
                                 selector: #selector(FaderNode.timerFired(_:)), userInfo: nil, repeats: true)
  }
  
  private func stopTimer() {
    if let currentTimer = timer {
      currentTimer.invalidate()
      timer = nil
    }
  }
  
  func timerFired(_ timer: Timer) {
    if shouldStopTimer {
      print("volume to \( Float(toVolume) ) (tovolume, timerFired)")
      playerNode.volume = Float(toVolume)
      stopTimer()
      callOnFinished(true)
      return
    }
    
    let currentTimeFrom0To1 = FaderNode.timeFrom0To1(
      currentStep, fadeDurationSeconds: fadeDurationSeconds, volumeAlterationsPerSecond: volumeAlterationsPerSecond)
    
    var volumeMultiplier: Double
    
    var newVolume: Double = 0
    
    if fadeIn {
      volumeMultiplier = FaderNode.fadeInVolumeMultiplier(currentTimeFrom0To1,
                                                      velocity: fadeVelocity)
      
      newVolume = fromVolume + (toVolume - fromVolume) * volumeMultiplier
      
    } else {
      volumeMultiplier = FaderNode.fadeOutVolumeMultiplier(currentTimeFrom0To1,
                                                       velocity: fadeVelocity)
      
      newVolume = toVolume - (toVolume - fromVolume) * volumeMultiplier
    }
    
    print("volume to \( Float(newVolume) ) (newvolume, timerFired)")
    playerNode.volume = Float(newVolume)
    
    currentStep += 1
  }
  
  var shouldStopTimer: Bool {
    let totalSteps = fadeDurationSeconds * volumeAlterationsPerSecond
    return Double(currentStep) > totalSteps
  }
  
  public class func timeFrom0To1(_ currentStep: Int, fadeDurationSeconds: Double,
                                 volumeAlterationsPerSecond: Double) -> Double {
    
    let totalSteps = fadeDurationSeconds * volumeAlterationsPerSecond
    var result = Double(currentStep) / totalSteps
    
    result = makeSureValueIsBetween0and1(result)
    
    return result
  }
  
  // Graph: https://www.desmos.com/calculator/wnstesdf0h
  public class func fadeOutVolumeMultiplier(_ timeFrom0To1: Double, velocity: Double) -> Double {
    let time = makeSureValueIsBetween0and1(timeFrom0To1)
    return pow(M_E, -velocity * time) * (1 - time)
  }
  
  public class func fadeInVolumeMultiplier(_ timeFrom0To1: Double, velocity: Double) -> Double {
    let time = makeSureValueIsBetween0and1(timeFrom0To1)
    return pow(M_E, velocity * (time - 1)) * time
  }
  
  private class func makeSureValueIsBetween0and1(_ value: Double) -> Double {
    if value < 0 { return 0 }
    if value > 1 { return 1 }
    return value
  }
}
