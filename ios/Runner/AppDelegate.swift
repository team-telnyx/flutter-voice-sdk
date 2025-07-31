import UIKit
import AVFAudio
import CallKit
import PushKit
import Flutter
import flutter_callkit_incoming
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
        print("[PUSH-DIAG] AppDelegate - onAccept called by CallKit for call ID: \\(call.uuid)")
        print("[PUSH-DIAG] AppDelegate - Call object: \\(call)")
        print("[PUSH-DIAG] AppDelegate - Call extra: \\(call.extra ?? [:])")
        action.fulfill()
        
    }
    
    func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        print("[PUSH-DIAG] AppDelegate - onDecline called by CallKit for call ID: \\(call.uuid)")
        print("[PUSH-DIAG] AppDelegate - Call extra: \\(call.extra ?? [:])")
        action.fulfill()
    }
    
    func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        print("[PUSH-DIAG] AppDelegate - onEnd called by CallKit for call ID: \\(call.uuid)")
        action.fulfill()
    }
    
    func onTimeOut(_ call: flutter_callkit_incoming.Call) {
        print("[PUSH-DIAG] AppDelegate - onTimeOut called by CallKit for call ID: \\(call.uuid)")
    }
    
    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        print("onRunner  :: Activate Audio Session")

        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }
    
    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
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
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
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
            print("[PUSH-DIAG] AppDelegate - ==================== INCOMING PUSH NOTIFICATION ====================")
            print("[PUSH-DIAG] AppDelegate - didReceiveIncomingPushWith payload: \\(payload.dictionaryPayload)")
            guard type == .voIP else { return }
            
            if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
                print("[PUSH-DIAG] AppDelegate - Metadata found in payload: \\(metadata)")
                
                var callID = UUID.init().uuidString
                if let newCallId = (metadata["call_id"] as? String),
                   !newCallId.isEmpty {
                    callID = newCallId
                }
                let callerName = (metadata["caller_name"] as? String) ?? ""
                let callerNumber = (metadata["caller_number"] as? String) ?? ""
                
                print("[PUSH-DIAG] AppDelegate - Extracted data: callID=\\(callID), callerName=\\(callerName), callerNumber=\\(callerNumber)")
                
                let id = payload.dictionaryPayload["call_id"] as? String ??  UUID().uuidString
                let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false
                
                let data = flutter_callkit_incoming.Data(id: id, nameCaller: callerName, handle: callerNumber, type: isVideo ? 1 : 0)
                data.extra = payload.dictionaryPayload as NSDictionary
                data.normalHandle = 1
                
                print("[PUSH-DIAG] AppDelegate - Setting data.extra to full payload: \\(payload.dictionaryPayload)")
                print("[PUSH-DIAG] AppDelegate - data.extra keys: \\(data.extra?.allKeys ?? [])")
              
                
                let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
                let uuid = UUID(uuidString: callID)
                
                //set more data
                //data.iconName = ...
                data.uuid = uuid!.uuidString
                data.nameCaller = caller
                
                print("[PUSH-DIAG] AppDelegate - Final CallKit data object:")
                print("[PUSH-DIAG] AppDelegate - data.uuid: \\(data.uuid)")
                print("[PUSH-DIAG] AppDelegate - data.nameCaller: \\(data.nameCaller)")
                print("[PUSH-DIAG] AppDelegate - data.handle: \\(data.handle)")
                print("[PUSH-DIAG] AppDelegate - data.extra: \\(data.extra ?? [:])")
                
                print("[PUSH-DIAG] AppDelegate - Calling showCallkitIncoming...")
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                   print("[PUSH-DIAG] AppDelegate - Calling completion() for didReceiveIncomingPushWith")
                   completion()
                }
            }
        }
    
    
}
