# Audio, AirPlay, CarPlay and phone calls

_Researched 2026-10-15 for F55. iOS, iPadOS and macOS; tvOS and visionOS share the iOS
session code and get the same settings._
_Companion docs: [OVERVIEW-AND-ARCHITECTURE.md](OVERVIEW-AND-ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md)_

---

## 1. The question

When Lytter is playing on an AirPlay speaker or in the car, can the phone take a call
without stopping the radio — the call on the handset, the radio carrying on where it is?

It depends on whether the call and the radio need the same speakers. Where they do not
(AirPlay), yes. Where they do (CarPlay, Bluetooth), no: the system gives the call the
speakers and stops the radio.

## 2. What each platform allows

| Where the radio plays | Through a call | How |
| --- | --- | --- |
| iPhone or iPad → AirPlay 2 speaker | **Keeps playing** | The `.longFormAudio` route-sharing policy. The radio plays on the output Music and Podcasts share; a call uses the device's own. Apple gives this as one of the policy's benefits: it lets the user "take a phone call while your app is AirPlaying" (WWDC17 509). |
| iPhone or iPad, any output, while the phone **rings** | **Keeps playing** when calls show as a banner | `setPrefersNoInterruptionsFromSystemAlerts(true)`. The session is interrupted only if the call is answered. With calls set to full screen it has no effect: the ring interrupts. |
| iPhone or iPad's own speaker or headphones, call answered | Pauses, resumes after | The call needs the same output. |
| CarPlay | Pauses, resumes after | The call plays through the car. Apple's CarPlay audio guide asks only that the app "resume audio where it left off without requiring user intervention" afterwards. |
| Bluetooth headphones or car Bluetooth (not CarPlay) | Pauses, resumes after | The call goes to the same headset or car. |
| Mac → AirPlay speaker through Lytter's own AirPlay button | **Keeps playing**, possibly quieter | The Mac's `AVRoutePickerView` is handed the player (`MacAirPlayButton` in [AirPlayButton.swift](../lytter/shared/views/AirPlayButton.swift)), so only Lytter goes to the speaker; a Continuity call answered on the Mac uses the Mac's own output. FaceTime lowers all other audio by about 20 dB while a call is on, and no app can opt out. |
| Mac with its *system* output set to the speaker | Not checked | Everything follows the system output, and the call may go to the speaker too. Lytter's own button is the one to use. |
| Mac, call answered on the iPhone | Unaffected | They are different devices. |

macOS has no `AVAudioSession`: no route-sharing policy, no interruptions. Nothing on the
Mac pauses Lytter for a call, so there is nothing there to change.

## 3. What Lytter does

- **The session is always long-form.** `AudioPlayerService.activateSession` sets
  `.playback`, mode `.default`, policy `.longFormAudio` on every activation. Until F55 only
  the resume after an interruption asked for long-form; play and resume asked for the
  default, which follows the device's route and is interrupted along with it.
- **Long-form from launch.** `lytter/Info.plist` sets `AVInitialRouteSharingPolicy` to
  `LongFormAudio` (Xcode: "AirPlay optimization policy"), so the AirPlay picker offers the
  long-form speakers before the first play has set the policy (WWDC23 10238).
- **A ringing phone does not stop the radio** (iOS and iPadOS): the same activation calls
  `setPrefersNoInterruptionsFromSystemAlerts(true)`. A failure there is logged and passed
  over; it does not keep the session from activating.
- **After a call, the listener's own Resume.** An interruption that ends with
  `.shouldResume` calls `resume()`: inside DR's live window (about 34 minutes) the radio
  carries on from where it stopped; past it, it reloads at live. `resume()` also restores
  `wantsPlayback`, so a stream that stalls afterwards is recovered, and reloads if the
  audio does not come back within four seconds. That reload activates the session again,
  which matters in CarPlay (§5).
- **What decides whether to resume** is unchanged: `InterruptionState`, which forgets the
  intent the moment the interruption ends.

There is no setting. Long-form is what Apple asks of a music or radio app, and it changes
nothing while the radio is not on AirPlay.

## 4. Ruled out

- **`.mixWithOthers`.** It would keep the radio playing through a call, but mixed into the
  call: in the car, the radio under the conversation. A mixable session is also never the
  Now Playing app, so it loses the lock screen, Control Centre and the CarPlay Now Playing
  screen — the controls a radio app needs most.
- **Keeping the radio playing in CarPlay.** The car's speakers are the call's. Moving the
  call to the handset mid-call is not expected to bring the radio back — the interruption
  has begun and does not end until the call does — though that has not been tried.
- **Telling AirPlay apart in code.** The system routes long-form audio to the AirPlay
  speaker and the call to the device by itself; the app never has to decide.

## 5. Known limits

- **Full-screen incoming calls interrupt on the ring**, whatever the app asks for
  (Settings → Apps → Phone → Incoming Calls).
- **AirPlay 2 is the case Apple describes.** An older AirPlay receiver, or one that
  streams in real time, has not been tried.
- **In CarPlay, activation can fail after a call.** Developers report the session
  refusing to activate (`cannotInterruptOthers`, 561015905) about half the time after a
  call while connected to CarPlay, in other apps as well as their own — a system state,
  not one app's bug. A tight retry loop does not help. Lytter retries once, through the
  reload four seconds later.
- **The Mac's FaceTime ducking** cannot be avoided by the app being ducked.

## 6. Checking it on devices

No simulator can place a call, and a real car needs the CarPlay entitlement (F21). The
unit tests (`AudioSessionPolicyTests`) pin down the settings and the resume; the rest is a
phone call from a second phone:

1. **iPhone → AirPlay 2 speaker** through Lytter's button, calls set to banner.
   Ringing: the radio carries on at the speaker. Answered: the call on the handset, the
   radio still at the speaker. Hung up: nothing changes.
2. **The same with full-screen calls.** Expected: the radio pauses on the ring and comes
   back after the call.
3. **iPhone speaker, banner.** Ringing: the radio carries on. Answered: it pauses. Hung
   up: it resumes — from where it stopped after a short call, at live after one longer than
   the window.
4. **iPad**, the same with a Continuity call.
5. **Mac → speaker** through Lytter's button. Answered on the Mac: the radio stays on the
   speaker, perhaps quieter. Answered on the iPhone: the Mac is unaffected.
6. **CarPlay**, once F21 is granted: the radio pauses for the call and comes back by itself.

## 7. Later

From iOS, tvOS and visionOS 27, `AVAudioSession.interruptionNotification` is deprecated in
favour of `didBecomeInactiveNotification` and `resumptionRecommendationNotification`,
which do not get stuck when an interruption's end is never delivered. The deployment
target is 17.6, so the legacy notification is still the right one and raises no warning;
move to the new pair when the target reaches 27.

## 8. Sources

- WWDC17 509, [Introducing AirPlay 2](https://developer.apple.com/videos/play/wwdc2017/509/) — long-form audio, and the call while AirPlaying.
- WWDC23 10238, [Tune up your AirPlay audio experience](https://developer.apple.com/videos/play/wwdc2023/10238/) — `AVInitialRouteSharingPolicy`, enhanced buffering in CarPlay.
- [`AVAudioSession.RouteSharingPolicy.longFormAudio`](https://developer.apple.com/documentation/avfaudio/avaudiosession/routesharingpolicy-swift.enum/longformaudio) and the `AVAudioSessionRouteSharingPolicy` header comment.
- [Playing custom audio with your own player](https://developer.apple.com/documentation/avfaudio/playing-custom-audio-with-your-own-player) — set long-form once, at startup.
- [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions) — calls as interruptions; the iOS 27 life-cycle notifications.
- [`setPrefersNoInterruptionsFromSystemAlerts(_:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:)) — banner versus full-screen calls.
- [CarPlay Audio App Programming Guide](https://developer.apple.com/carplay/documentation/CarPlay-Audio-App-Programming-Guide.pdf) — "Audio playback after interruptions".
- Developer forums: [810282](https://developer.apple.com/forums/thread/810282) and [782759](https://developer.apple.com/forums/thread/782759) (activation failing in CarPlay), [653606](https://developer.apple.com/forums/thread/653606) (the system switching to long-form on AirPlay).
- AppleVis, [FaceTime ducking all other audio](https://applevis.com/comment/185008) — a user report, not Apple's.
