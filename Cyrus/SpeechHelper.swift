//
//  SpeechHelper.swift
//  Cyrus
//
//  Created by Josue Espinosa on 12/23/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import Foundation
import Speech

class SpeechHelper: NSObject, SFSpeechRecognitionTaskDelegate, SFSpeechRecognizerDelegate {
    // audio engine processes the audio stream and gives updates when the mic is receiving audio
    private static let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    // recognition request allocates speech as the user speaks in real-time and controls the buffering
    private static var recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    // recognition task used to manage, cancel, or stop the current recognition task
    private static var recognitionTask: SFSpeechRecognitionTask?
    // speech recognizer can fail to recognize speech and return nil, mark it as optional
    private static let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private static let speechSynthesizer = AVSpeechSynthesizer()

    static func requestAuthorization(completion:
        @escaping (_ authorizationStatus: SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization { (authorizationStatus: SFSpeechRecognizerAuthorizationStatus) in
            OperationQueue.main.addOperation {
                completion(authorizationStatus)
            }
        }
    }

    static func recordSpeech(newTranscriptionAvailable: @escaping (_ newTranscription: String) -> Void) {
        // audioEngine uses inputNode to process bits of audio
        let inputNode = audioEngine.inputNode
        // inputNode creates a singleton for the incoming audio
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // installTap configures the node and sets up the request instance with the proper buffer on the proper bus
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print(error)
        }

        guard let recognizer = SFSpeechRecognizer() else {
            return print("Error: SFSpeechRecognizer does not support the current locale")
        }
        if !recognizer.isAvailable {
            print("Error: SFSpeechRecognizer is not available right now")
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest,
                                                            resultHandler: { (result, error) in
            if result != nil {
                if let result = result {
                    newTranscriptionAvailable(result.bestTranscription.formattedString)
                }
            } else if let error = error {
                print(error)
            }
        })
    }

    static func stopRecordingSpeech() {
        recognitionRequest.endAudio()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
    }

    static func speak(transcript: String) {
        let speechUtterance = AVSpeechUtterance(string: transcript)
        speechSynthesizer.speak(speechUtterance)
    }

    static func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

}
