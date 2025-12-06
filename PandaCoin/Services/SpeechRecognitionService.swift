//
//  SpeechRecognitionService.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - 语音识别服务
class SpeechRecognitionService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    // MARK: - Recording Control
    func startRecording() throws {
        // 检查权限
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch currentStatus {
        case .notDetermined:
            // 未请求过权限，弹出系统授权框
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    if status == .authorized {
                        // 授权成功后重试启动
                        try? self?.startRecording()
                    } else {
                        self?.errorMessage = "需要语音识别权限才能使用此功能"
                    }
                }
            }
            throw SpeechRecognitionError.notAuthorized
            
        case .denied, .restricted:
            // 用户拒绝或被限制，提示去设置中打开
            throw SpeechRecognitionError.needsSettingsAuthorization
            
        case .authorized:
            // 已授权，继续执行
            break
            
        @unknown default:
            throw SpeechRecognitionError.notAuthorized
        }
        
        // 检查识别器可用性
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }
        
        // 如果已有任务在运行,先取消
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.cannotCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true // 实时返回结果
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        
        // 开始识别任务
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
        
        // 配置音频录制格式
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recognizedText = ""
            self.errorMessage = nil
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        
        isRecording = false
    }
    
    // MARK: - Cleanup
    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}

// MARK: - Speech Recognition Errors
enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case needsSettingsAuthorization
    case recognizerNotAvailable
    case cannotCreateRequest
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "需要语音识别权限"
        case .needsSettingsAuthorization:
            return "请在设置中允许访问语音识别"
        case .recognizerNotAvailable:
            return "语音识别服务暂时不可用"
        case .cannotCreateRequest:
            return "无法创建识别请求"
        }
    }
}
