import UIKit
import AVFAudio
import CallKit
import PushKit
import Flutter
import flutter_callkit_incoming
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    private let audioRaceChannelName = "org.telnyx.webrtc/audio-race-debug"
    private var audioLifecycleGeneration = 0
    #if DEBUG
    private var audioRaceChannel: FlutterMethodChannel?
    #endif

    private func activateWebRTCAudio(_ audioSession: AVAudioSession, reason: String) {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        let wasAudioEnabled = rtcAudioSession.isAudioEnabled
        print("[CALLKIT_AUDIO] Activating WebRTC audio (\(reason)); enabled=\(rtcAudioSession.isAudioEnabled)")
        rtcAudioSession.lockForConfiguration()
        let configuration = RTCAudioSessionConfiguration.webRTC()
        configuration.categoryOptions = [.duckOthers, .allowBluetooth]
        do {
            try rtcAudioSession.setConfiguration(configuration)
        } catch {
            print("[CALLKIT_AUDIO] Configuration failed: \(error)")
        }

        var activationSucceeded = false
        do {
            try rtcAudioSession.setActive(true)
            activationSucceeded = true
        } catch {
            print("[CALLKIT_AUDIO] Activation failed: \(error)")
        }
        rtcAudioSession.isAudioEnabled = activationSucceeded
        rtcAudioSession.unlockForConfiguration()
        if activationSucceeded && !wasAudioEnabled {
            rtcAudioSession.audioSessionDidActivate(audioSession)
        }
    }

    func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
        print("[iOS_PUSH_DEBUG] AppDelegate - onAccept called by CallKit for call ID: \\(call.uuid)")
        audioLifecycleGeneration += 1
        let verificationGeneration = audioLifecycleGeneration
        action.fulfill()
        verifyAudioAfterAnswer(generation: verificationGeneration)
    }

    private func verifyAudioAfterAnswer(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard self?.audioLifecycleGeneration == generation else {
                print("[CALLKIT_AUDIO] Skipping stale post-answer verification")
                return
            }
            let rtcAudioSession = RTCAudioSession.sharedInstance()
            if rtcAudioSession.isAudioEnabled {
                print("[CALLKIT_AUDIO] Post-answer verification passed")
            } else if AVAudioSession.sharedInstance().category == .playAndRecord {
                print("[CALLKIT_AUDIO] Recovering disabled audio after CallKit answer")
                self?.activateWebRTCAudio(
                    AVAudioSession.sharedInstance(),
                    reason: "post-answer verification"
                )
            } else {
                print("[CALLKIT_AUDIO] Verification skipped; CallKit session is not active")
            }
        }
    }
    
    func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        audioLifecycleGeneration += 1
        print("onRunner ::  Decline")
        action.fulfill()
    }
    
    func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        audioLifecycleGeneration += 1
        print("onRunner ::  End")
        action.fulfill()
    }
    
    func onTimeOut(_ call: flutter_callkit_incoming.Call) {
        audioLifecycleGeneration += 1
        print("onRunner ::  TimeOut")
    }
    
    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        print("onRunner  :: Activate Audio Session")
        activateWebRTCAudio(audioSession, reason: "CallKit didActivate")
    }
    
    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        audioLifecycleGeneration += 1
        print("onRunner  :: DeActivate Audio Session")

        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      
      //Setup VOIP
      let mainQueue = DispatchQueue.main
      let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
      voipRegistry.delegate = self
      voipRegistry.desiredPushTypes = [PKPushType.voIP]

      RTCAudioSession.sharedInstance().useManualAudio = true
      RTCAudioSession.sharedInstance().isAudioEnabled = false

      let didFinishLaunching = super.application(
          application,
          didFinishLaunchingWithOptions: launchOptions
      )

      #if DEBUG
      DispatchQueue.main.async { [weak self] in
          self?.installAudioRaceDebugChannel()
      }
      #endif

      return didFinishLaunching
  }

    #if DEBUG
    private func installAudioRaceDebugChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("[VSUP-226] Audio race channel unavailable: missing FlutterViewController")
            return
        }
        let channel = FlutterMethodChannel(
            name: audioRaceChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "simulateAudioSetupRace" else {
                result(FlutterMethodNotImplemented)
                return
            }
            let delayMilliseconds =
                (call.arguments as? [String: Any])?["delayMilliseconds"] as? Int ?? 250
            self?.simulateAudioSetupRace(delay: Double(delayMilliseconds) / 1_000)
            result(["scheduled": true, "delayMilliseconds": delayMilliseconds])
        }
        audioRaceChannel = channel
    }

    private func simulateAudioSetupRace(delay: TimeInterval) {
        print("[VSUP-226] Scheduling late audio reset in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            RTCAudioSession.sharedInstance().isAudioEnabled = false
            print("[VSUP-226] Injected late setup reset; enabled=false")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self?.activateWebRTCAudio(
                    AVAudioSession.sharedInstance(),
                    reason: "debug connected-call recovery"
                )
            }
        }
    }
    #endif
    
    // Call back from Recent history
        override func application(_ application: UIApplication,
                                  continue userActivity: NSUserActivity,
                                  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
            
            guard let handleObj = userActivity.handle else {
                return false
            }
            
            guard let isVideo = userActivity.isVideo else {
                return false
            }
            let nameCaller = handleObj.getDecryptHandle()["nameCaller"] as? String ?? ""
            let handle = handleObj.getDecryptHandle()["handle"] as? String ?? ""
            let data = flutter_callkit_incoming.Data(id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
            //set more data...
            data.nameCaller = "Johnny"
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)
            
        
            return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        
        // Handle updated push credentials
        func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
            print(credentials.token)
            let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
            print(deviceToken)
            //Save deviceToken to your server
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
        }
        
        func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
            print("didInvalidatePushTokenFor")
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
        }
        
        // Handle incoming pushes
        func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
            print("[iOS_PUSH_DEBUG] AppDelegate - didReceiveIncomingPushWith payload: \\(payload.dictionaryPayload)")
            guard type == .voIP else { return }
            
            // Check for missed call notification (SDK 4.0.0+)
            if let aps = payload.dictionaryPayload["aps"] as? [String: Any],
               let alert = aps["alert"] as? String,
               alert == "Missed call!" {
                print("[iOS_PUSH_DEBUG] AppDelegate - Received missed call notification, dismissing CallKit")
                
                if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
                    var callID = UUID().uuidString
                    if let newCallId = metadata["call_id"] as? String, !newCallId.isEmpty {
                        callID = newCallId
                    }
                    
                    // End the call to dismiss CallKit UI
                    let data = flutter_callkit_incoming.Data(id: callID, nameCaller: "", handle: "", type: 0)
                    data.uuid = callID
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
                    print("[iOS_PUSH_DEBUG] AppDelegate - Called endCall for missed call UUID: \\(callID)")
                }
                
                completion()
                return
            }
            
            if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
                var callID = UUID.init().uuidString
                if let newCallId = (metadata["call_id"] as? String),
                   !newCallId.isEmpty {
                    callID = newCallId
                }
                let callerName = (metadata["caller_name"] as? String) ?? ""
                let callerNumber = (metadata["caller_number"] as? String) ?? ""
                
                let id = payload.dictionaryPayload["call_id"] as? String ??  UUID().uuidString
                let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false
                
                let data = flutter_callkit_incoming.Data(id: id, nameCaller: callerName, handle: callerNumber, type: isVideo ? 1 : 0)
                data.extra = payload.dictionaryPayload as NSDictionary
                data.normalHandle = 1
                print("\(callerName)")
              
                
                let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
                let uuid = UUID(uuidString: callID)
                
                //set more data
                //data.iconName = ...
                data.uuid = uuid!.uuidString
                data.nameCaller = caller
                print("[iOS_PUSH_DEBUG] AppDelegate - Before SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming. Data: \\(data)")
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                   print("[iOS_PUSH_DEBUG] AppDelegate - Calling completion() for didReceiveIncomingPushWith")
                   completion()
                }
            }
        }
    
    
}
