This guide helps you troubleshoot common issues that prevent push notifications from being delivered in the Telnyx WebRTC Flutter SDK.

## Introduction

Push notifications in Flutter applications require proper configuration on both the Flutter side and the native platform sides (iOS and Android). Since Flutter is a cross-platform framework, troubleshooting push notifications often involves checking platform-specific configurations.

Common issues that affect both platforms:

1. **Push Token Not Passed to Login**: Ensure your push token is correctly retrieved and passed during login
2. **Wrong Push Credential Assigned to SIP Connection**: Verify your SIP connection has the correct push credential assigned
3. **Network Connectivity Issues**: Check that your device has a stable internet connection

## Android Troubleshooting

### 1. FCM Token Not Passed to Login

One of the most common issues is that the FCM token is not being passed correctly during the login process.

**How to verify:**
- Check your application logs to ensure the FCM token is being retrieved successfully
- Verify that the login message contains the FCM token
- Look for logs similar to: `FCM token received: [your-token]`

**Solution:**
- Make sure you're retrieving the FCM token as shown in the [App Setup](https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/push-notification/app-setup) guide
- Ensure the token is passed to the `connect()` method within the `TelnyxConfig` object
- Verify that the token is not null or empty before passing it
### 2. Incorrect google-services.json Configuration

If your Firebase configuration file is incorrect or outdated, push notifications will not work properly.

**How to verify:**
- Check that the google-services.json file is in the correct location (android/app/ directory)
- Verify that the package name in the google-services.json matches your application's package name

**Solution:**
- Download a fresh copy of the google-services.json file from the Firebase Console
- Make sure you're using the correct Firebase project for your application
- Follow the [Portal Setup](https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/push-notification/portal-setup) guide to properly configure Firebase

### 3. Incorrect Push Credential

If your push credential contains incorrect information, push notifications will fail.

**How to verify:**
- Check the push credential in the Telnyx Portal
- Verify that the server key JSON is correctly formatted and valid

**Solution:**
- Generate a new server key in the Firebase Console
- Update your push credential in the Telnyx Portal with the new key
- Test push notifications after updating the credential

### 4. Delayed or Batched Notifications (Android 8+)

**Symptom:**
Notifications (especially for incoming calls) are not arriving immediately when the app is in the background or terminated. They might arrive in batches after some delay.

**Cause:**
Android includes power-saving features like Doze mode and App Standby that can defer background network access and job execution for apps using `normal` priority Firebase Cloud Messages (FCM).

**Solutions:**

1. **Create High-Importance Notification Channel (Client-Side - For Display):**
    *   While server-side priority affects *delivery speed*, a client-side Notification Channel with `Importance.max` is crucial for ensuring the notification is *displayed* promptly as a heads-up notification once delivered (on Android 8.0+).
    *   Make sure you have created this channel using `flutter_local_notifications` during your app initialization, as described in the [App Setup Guide](https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/push-notification/app-setup).
    *   **Verification Code Snippet:**
        ```dart
        // Example (should be in your initialization code)
        import 'package:flutter_local_notifications/flutter_local_notifications.dart';

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'telnyx_call_channel', 
          'Incoming Calls', 
          description: 'Notifications for incoming Telnyx calls.',
          importance: Importance.max,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        );
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        ```

2. **Check `AndroidManifest.xml`:**
    *   Ensure you have added the `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="your_channel_id" />` tag inside your `<application>` tag, where `your_channel_id` matches the ID used when creating the channel (e.g., `telnyx_call_channel`). This helps Firebase use the correct channel if it ever displays a notification directly.

3. **Enable Core Library Desugaring (Gradle Setup):**
    *   If you encounter build failures like `CheckDebugAarMetadata` or runtime errors related to missing Java APIs after adding `flutter_local_notifications` or similar plugins, you likely need to enable Core Library Desugaring.
    *   In your `android/app/build.gradle` (Groovy DSL):
        ```groovy
        android {
            // ...
            compileOptions {
                coreLibraryDesugaringEnabled true
                sourceCompatibility JavaVersion.VERSION_1_8 // or VERSION_11
                targetCompatibility JavaVersion.VERSION_1_8 // or VERSION_11
            }
            kotlinOptions {
                jvmTarget = "1.8" // or "11"
            }
            // ...
        }

        dependencies {
            // ...
            coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4' // Or newer, e.g., 2.1.4 for Java 11 support
        }
        ```

    *   For projects using **Kotlin DSL (`build.gradle.kts`):**
        ```kotlin
        // android/app/build.gradle.kts (Kotlin DSL)
        android {
            // ... other settings
            defaultConfig {
                // multiDexEnabled = true // Only if you explicitly need multidex for other reasons
            }

            compileOptions {
                isCoreLibraryDesugaringEnabled = true
                sourceCompatibility = JavaVersion.VERSION_1_8 // Or JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_1_8 // Or JavaVersion.VERSION_11
            }

            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_1_8.toString() // Or JavaVersion.VERSION_11.toString()
            }
            // ... other settings
        }

        dependencies {
            // ... other dependencies
            coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Or a newer version like 2.1.4 for Java 11
        }
        ```
    *   This allows your app to use Java 8+ language APIs on older Android versions. Refer to the official [Android Java 8+ support documentation](https://developer.android.com/studio/write/java8-support) and the specific plugin's documentation (like `flutter_local_notifications`) for the recommended Java version and `desugar_jdk_libs` version.

4. **Foreground Service (Advanced):**
    *   For maximum reliability, especially for critical call signaling, consider implementing an Android Foreground Service (using a plugin like `flutter_foreground_task`) to handle the incoming FCM message. This gives your background processing higher priority. Refer to Android best practices for call-related apps.

### 5. Additional Android Troubleshooting Steps

1. **Check Firebase Console Logs**
   - Go to the Firebase Console > Your Project > Engage > Messaging
   - Check for any errors or failed deliveries

2. **Test with Firebase Test Notifications**
   - Use the Firebase Console to send a test notification to your device
   - This can help determine if the issue is with Firebase or with Telnyx

3. **Verify Device Registration**
   - Make sure your device is properly registered with Firebase
   - Check that the FCM token is being refreshed when needed

## iOS Troubleshooting

### 1. VoIP Push Notification Certificate

One of the most critical components for iOS push notifications is the VoIP Push Notification Certificate. A single VoIP Services Certificate supports both sandbox and production environments for the same bundle ID.

**How to verify:**
- Check that you have generated a valid VoIP Services Certificate in the Apple Developer Portal
- Verify that the certificate is not expired
- Ensure the certificate is generated for the correct bundle ID used in your app
- Verify that the VoIP Services Certificate establishes connectivity between your notification server and both APNS sandbox and production environments

**Solution:**
- Follow [Apple's official documentation](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_certificate-based_connection_to_apns) to generate a new VoIP Services Certificate
- Upload the certificate to the Telnyx Portal
- Ensure the certificate matches your app's bundle ID
- For different bundle IDs (e.g., com.myapp.dev, com.myapp), create separate VoIP Services Certificates
- Note: A separate certificate is required for each app you distribute, but each certificate works for both sandbox and production

### 2. APNS Environment Mismatch

iOS apps can target either the APNS Sandbox (development) or Production environment, and this must align with your build configuration.

**How to verify:**
- Check your build configuration (Debug vs Release)
- Ensure that the APNS environment setting in your TxConfig (`pushEnvironment` property) is not being forced
- Confirm that the correct VoIP Services Certificate, valid for both production and development, is uploaded to the Telnyx Portal

**Solution:**
- For Debug builds running from Xcode:
  * Use a Sandbox (development) certificate
  * Set `pushEnvironment` to `sandbox` in TelnyxConfig if needed
- For Release builds or TestFlight:
  * Use a Production certificate
  * Set `pushEnvironment` to `production` in TelnyxConfig if needed
- If generating an IPA:
  * Ensure it's signed with the correct profile (development or distribution)
  * Match the APNS environment to your signing profile

### 3. Info.plist Configuration

Proper configuration in Info.plist is essential for push notifications to work.

**How to verify:**
- Check that push notifications are enabled in your app's capabilities
- Verify that VoIP push notifications are properly configured
- Ensure background modes are enabled for VoIP

**Solution:**
- Add the following to your Info.plist:
  ```html
  <key>UIBackgroundModes</key>
  <array>
      <string>voip</string>
  </array>
  ```
- Enable "Voice over IP" and "Background fetch" in Xcode capabilities
- Verify that your app has the required entitlements for push notifications

### 4. Additional iOS Troubleshooting Steps

1. **Check APNS Status**
   - Use Apple's developer tools to verify APNS connectivity
   - Monitor for any APNS feedback about invalid tokens or delivery failures

2. **Verify Bundle ID Configuration**
   - Ensure your bundle ID matches across:
     * Xcode project settings
     * Provisioning profiles
     * VoIP push certificates
     * Telnyx Portal configuration

3. **Test with Development Environment First**
   - Start testing with sandbox/development environment
   - Use debug builds and development certificates
   - Monitor system logs for push notification related messages

## Still Having Issues?

If you've gone through all the troubleshooting steps and are still experiencing problems:

1. Check the Telnyx WebRTC Flutter SDK documentation for any updates or known issues
2. Contact Telnyx Support with detailed information about your setup and the issues you're experiencing
3. Include logs, error messages, and steps to reproduce the problem when contacting support
4. Provide your development environment details:
   - Flutter version
   - iOS/Android version
   - SDK version
   - Build configuration (Debug/Release)
   - Certificate type (Development/Production for iOS)
