//
//  ZLCustomCamera.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/11.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import AVFoundation
import CoreMotion

open class ZLCustomCamera: UIViewController {
    public enum Layout {
        static let bottomViewH: CGFloat = 120
        static let largeCircleRadius: CGFloat = 80
        static let smallCircleRadius: CGFloat = 65
        static let largeCircleRecordScale: CGFloat = 1.2
        static let smallCircleRecordScale: CGFloat = 0.5
        static let borderLayerWidth: CGFloat = 1.8
        static let animateLayerWidth: CGFloat = 5
        static let cameraBtnNormalColor: UIColor = .white
        static let cameraBtnRecodingBorderColor: UIColor = .white.withAlphaComponent(0.8)
    }
    
    @objc public var takeDoneBlock: ((UIImage?, URL?) -> Void)?
    
    @objc public var takesDoneBlock: (([UIImage], URL?) -> Void)?
    
    @objc public var cancelBlock: (() -> Void)?

    /// An optional block that gets called right before photo capture or video recording starts.
    /// - Parameters:
    ///   - completion: Call this closure when you want the camera to proceed with capture.
    ///   - isCapturing: Boolean indicating if a capture operation is already in progress
    //  (e.g. during camera switch while recording). If true, you might want to skip countdown or effects.
    @objc public var willCaptureBlock: ((@escaping () -> Void, _ isCapturing: Bool) -> Void)?
    
    public lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.font = .zl.font(ofSize: 14)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.alpha = 0
        return label
    }()
    
    public lazy var bottomView = UIView()
    
    public lazy var largeCircleView: UIView = {
        let view = UIView()
        view.layer.addSublayer(borderLayer)
        return view
    }()
    
    public lazy var smallCircleView: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = ZLCustomCamera.Layout.smallCircleRadius / 2
        view.isUserInteractionEnabled = false
        view.backgroundColor = ZLCustomCamera.Layout.cameraBtnNormalColor
        return view
    }()
    
    public lazy var borderLayer: CAShapeLayer = {
        let animateLayerRadius = ZLCustomCamera.Layout.largeCircleRadius
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: animateLayerRadius, height: animateLayerRadius), cornerRadius: animateLayerRadius / 2)
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = ZLCustomCamera.Layout.cameraBtnNormalColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = ZLCustomCamera.Layout.borderLayerWidth
        return layer
    }()
    
    public lazy var animateLayer: CAShapeLayer = {
        let animateLayerRadius = ZLCustomCamera.Layout.largeCircleRadius
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: animateLayerRadius, height: animateLayerRadius), cornerRadius: animateLayerRadius / 2)
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = UIColor.zl.cameraRecodeProgressColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = ZLCustomCamera.Layout.animateLayerWidth
        layer.lineCap = .round
        return layer
    }()
    
    public lazy var retakeBtn: ZLEnlargeButton = {
        let btn = ZLEnlargeButton(type: .custom)
        btn.setImage(.zl.getImage("zl_retake"), for: .normal)
        btn.addTarget(self, action: #selector(retakeBtnClick), for: .touchUpInside)
        btn.isHidden = true
        btn.adjustsImageWhenHighlighted = false
        btn.enlargeInset = 30
        return btn
    }()
    
    public lazy var doneBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.font = ZLLayout.bottomToolTitleFont
        btn.setTitle(localLanguageTextValue(.cameraDone), for: .normal)
        btn.setTitleColor(.zl.bottomToolViewDoneBtnNormalTitleColor, for: .normal)
        btn.backgroundColor = .zl.bottomToolViewBtnNormalBgColor
        btn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        btn.isHidden = true
        btn.layer.masksToBounds = true
        btn.layer.cornerRadius = ZLLayout.bottomToolBtnCornerRadius
        return btn
    }()
    
    public lazy var dismissBtn: ZLEnlargeButton = {
        let btn = ZLEnlargeButton(type: .custom)
        btn.setImage(.zl.getImage("zl_camera_close"), for: .normal)
        btn.addTarget(self, action: #selector(dismissBtnClick), for: .touchUpInside)
        btn.adjustsImageWhenHighlighted = false
        btn.enlargeInset = 30
        return btn
    }()
    
    public lazy var flashBtn: ZLEnlargeButton = {
        let btn = ZLEnlargeButton(type: .custom)
        btn.setImage(.zl.getImage("zl_flash_off"), for: .normal)
        btn.setImage(.zl.getImage("zl_flash_on"), for: .selected)
        btn.addTarget(self, action: #selector(flashBtnClick), for: .touchUpInside)
        btn.adjustsImageWhenHighlighted = false
        btn.enlargeInset = 30
        return btn
    }()
    
    public lazy var switchCameraBtn: ZLEnlargeButton = {
        let cameraCount = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices.count
        
        let btn = ZLEnlargeButton(type: .custom)
        btn.setImage(.zl.getImage("zl_toggle_camera"), for: .normal)
        btn.addTarget(self, action: #selector(switchCameraBtnClick), for: .touchUpInside)
        btn.adjustsImageWhenHighlighted = false
        btn.enlargeInset = 30
        btn.isHidden = !cameraConfig.allowSwitchCamera || cameraCount <= 1
        return btn
    }()
    
    public lazy var focusCursorView: UIImageView = {
        let view = UIImageView(image: .zl.getImage("zl_focus"))
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.frame = CGRect(x: 0, y: 0, width: 70, height: 70)
        view.alpha = 0
        return view
    }()
    
    public lazy var takedImageView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = .black
        view.isHidden = true
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private var hideTipsTimer: Timer?
    
    private var takedImage: UIImage?
    
    public var takedCount: Int = 1
    
    // 存储拍摄的图片，需要拍摄多张时
    private var takedImages: [UIImage] = []
    
    private var videoURL: URL?
    
    private var motionManager: CMMotionManager?
    
    private var orientation: AVCaptureVideoOrientation = .portrait
    
    private var torchDevice = AVCaptureDevice.default(for: .video)
    
    private let sessionQueue = DispatchQueue(label: "com.zl.camera.sessionQueue")
    
    private let session = AVCaptureSession()
    
    private var videoInput: AVCaptureDeviceInput?
    
    private var imageOutput: AVCapturePhotoOutput?
    
    private var movieFileOutput: AVCaptureMovieFileOutput?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var recordVideoPlayerLayer: AVPlayerLayer?
    
    private var cameraConfigureFinish = false
    
    private var shouldLayout = true
    
    private var dragStart = false
    
    private var viewDidAppearCount = 0
    
    private var restartRecordAfterSwitchCamera = false
    
    private var isSwitchingCamera = false
    
    private var cacheVideoOrientation: AVCaptureVideoOrientation = .portrait
    
    private var recordURLs: [URL] = []
    
    private var recordDurations: [Double] = []
    
    private var microPhontIsAvailable = true
    
    private var isCapturePending = false
    
    private lazy var focusCursorTapGes: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action: #selector(adjustFocusPoint))
        tap.delegate = self
        return tap
    }()
    
    private var cameraFocusPanGes: UIPanGestureRecognizer?
    
    private var recordLongGes: UILongPressGestureRecognizer?
    
    /// 是否正在调整焦距
    private var isAdjustingFocusPoint = false
    
    /// 是否正在拍照
    private var isTakingPicture = false
    
    private var showFlashBtn = true {
        didSet {
            flashBtn.isHidden = !showFlashBtn
        }
    }
    
    private var shouldUseTapToRecord: Bool {
        cameraConfig.tapToRecordVideo && !cameraConfig.allowTakePhoto
    }
    
    private lazy var cameraConfig = ZLPhotoConfiguration.default().cameraConfiguration
    
    /// Automatically stops recording video after maxRecordDuration on tapToRecordVideo.
    private var autoStopTimer: Timer?
    
    private var canEditImage: Bool {
        ZLPhotoConfiguration.default().allowEditImage
    }
    
    // 仅支持竖屏
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        deviceIsiPhone() ? .portrait : .all
    }
    
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    deinit {
        zl_debugPrint("ZLCustomCamera deinit")
        cleanAutoStopTimer()
        cleanTimer()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    @objc public init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            guard videoGranted else {
                ZLMainAsync(after: 1) {
                    self.showAlertAndDismissAfterDoneAction(message: String(format: localLanguageTextValue(.noCameraAuthorityAlertMessage), getAppName()), type: .camera)
                }
                return
            }
            
            guard self.cameraConfig.allowRecordVideo else {
                self.addNotification()
                return
            }
            
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                self.addNotification()
                if !audioGranted {
                    ZLMainAsync(after: 1) {
                        self.shownoMicrophoneAuthorityAlertMessageAlert()
                    }
                }
            }
        }
        
        if cameraConfig.allowRecordVideo {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: .duckOthers)
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                let err = error as NSError
                if err.code == AVAudioSession.ErrorCode.insufficientPriority.rawValue ||
                    err.code == AVAudioSession.ErrorCode.isBusy.rawValue {
                    microPhontIsAvailable = false
                }
            }
        }
        
        setupCamera()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observerDeviceMotion()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            showAlertAndDismissAfterDoneAction(message: localLanguageTextValue(.cameraUnavailable), type: .camera)
        } else if !cameraConfig.allowTakePhoto, !cameraConfig.allowRecordVideo {
            #if DEBUG
                fatalError("Error configuration of camera")
            #else
                showAlertAndDismissAfterDoneAction(message: "Error configuration of camera", type: nil)
            #endif
        } else if cameraConfigureFinish, viewDidAppearCount == 0 {
            showTipsLabel(message: cameraUsageTipsText())
            let animation = ZLAnimationUtils.animation(type: .fade, fromValue: 0, toValue: 1, duration: 0.15)
            previewLayer?.add(animation, forKey: nil)
            setFocusCusor(point: view.center)
        }
        viewDidAppearCount += 1
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard session.isRunning else { return }
        
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        shouldLayout = true
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard shouldLayout else { return }
        shouldLayout = false
        
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = self.view.safeAreaInsets
        }
        
        let cameraRatio: CGFloat = 16 / 9
        let layerH = min(view.zl.width * cameraRatio, view.zl.height)
        
        let previewLayerY: CGFloat
        if isSmallScreen() {
            previewLayerY = deviceIsFringeScreen() ? min(94, view.zl.height - layerH) : 0
        } else {
            previewLayerY = 0
        }
        
        let previewFrame = CGRect(x: 0, y: previewLayerY, width: view.bounds.width, height: layerH)
        previewLayer?.frame = previewFrame
        recordVideoPlayerLayer?.frame = previewFrame
        takedImageView.frame = previewFrame
        cameraConfig.overlayView?.frame = previewFrame // Layout custom overlay view.
        
        dismissBtn.frame = CGRect(x: 20, y: 60, width: 30, height: 30)
        retakeBtn.frame = CGRect(x: 20, y: 60, width: 28, height: 28)
        
        var bottomViewToBottomSpacing = view.zl.height - insets.bottom - ZLCustomCamera.Layout.bottomViewH
        if view.zl.height <= 812 {
            bottomViewToBottomSpacing -= deviceIsFringeScreen() ? 40 : 20
        }
        
        bottomView.frame = CGRect(x: 0, y: bottomViewToBottomSpacing, width: view.bounds.width, height: ZLCustomCamera.Layout.bottomViewH)
        let largeCircleH = ZLCustomCamera.Layout.largeCircleRadius
        largeCircleView.frame = CGRect(x: (view.bounds.width - largeCircleH) / 2, y: (ZLCustomCamera.Layout.bottomViewH - largeCircleH) / 2, width: largeCircleH, height: largeCircleH)
        let smallCircleH = ZLCustomCamera.Layout.smallCircleRadius
        smallCircleView.frame = CGRect(x: (view.bounds.width - smallCircleH) / 2, y: (ZLCustomCamera.Layout.bottomViewH - smallCircleH) / 2, width: smallCircleH, height: smallCircleH)
        
        flashBtn.frame = CGRect(x: 60, y: (ZLCustomCamera.Layout.bottomViewH - 25) / 2, width: 25, height: 25)
        switchCameraBtn.frame = CGRect(x: bottomView.zl.width - 60 - 25, y: flashBtn.zl.top, width: 25, height: 25)
        
        let tipsTextHeight = (tipsLabel.text ?? " ").zl
            .boundingRect(
                font: .zl.font(ofSize: 14),
                limitSize: CGSize(width: view.bounds.width - 20, height: .greatestFiniteMagnitude)
            )
            .height + 30
        tipsLabel.frame = CGRect(x: 10, y: bottomView.frame.minY - tipsTextHeight, width: view.bounds.width - 20, height: tipsTextHeight)
        
        let doneBtnW = (doneBtn.currentTitle ?? "")
            .zl.boundingRect(
                font: ZLLayout.bottomToolTitleFont,
                limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 40)
            )
            .width + 20
        let doneBtnY = view.bounds.height - 57 - insets.bottom
        doneBtn.frame = CGRect(x: view.bounds.width - doneBtnW - 20, y: doneBtnY, width: doneBtnW, height: ZLLayout.bottomToolBtnH)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(dismissBtn)
        view.addSubview(takedImageView)
        view.addSubview(focusCursorView)
        view.addSubview(tipsLabel)
        view.addSubview(bottomView)
        
        if let overlayView = cameraConfig.overlayView {
            view.addSubview(overlayView)  // Add custom overlay view.
        }
        
        bottomView.addSubview(flashBtn)
        bottomView.addSubview(largeCircleView)
        bottomView.addSubview(smallCircleView)
        bottomView.addSubview(switchCameraBtn)
        
        var takePictureTap: UITapGestureRecognizer?
        if cameraConfig.allowTakePhoto {
            takePictureTap = UITapGestureRecognizer(target: self, action: #selector(takePicture))
            largeCircleView.addGestureRecognizer(takePictureTap!)
        }
        if cameraConfig.allowRecordVideo {
            if shouldUseTapToRecord {
                let takeVideoTap = UITapGestureRecognizer(target: self, action: #selector(tapToRecordAction(_:)))
                largeCircleView.addGestureRecognizer(takeVideoTap)
            } else {
                let longGes = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
                longGes.minimumPressDuration = 0.3
                longGes.delegate = self
                largeCircleView.addGestureRecognizer(longGes)
                takePictureTap?.require(toFail: longGes)
                recordLongGes = longGes

                let panGes = UIPanGestureRecognizer(target: self, action: #selector(adjustCameraFocus(_:)))
                panGes.delegate = self
                panGes.maximumNumberOfTouches = 1
                largeCircleView.addGestureRecognizer(panGes)
                cameraFocusPanGes = panGes
            }
            
            recordVideoPlayerLayer = AVPlayerLayer()
            recordVideoPlayerLayer?.backgroundColor = UIColor.black.cgColor
            recordVideoPlayerLayer?.videoGravity = .resizeAspect
            recordVideoPlayerLayer?.isHidden = true
            view.layer.insertSublayer(recordVideoPlayerLayer!, at: 0)
            
            NotificationCenter.default.addObserver(self, selector: #selector(recordVideoPlayFinished), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
        
        view.addSubview(retakeBtn)
        view.addSubview(doneBtn)
        
        // 预览layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.opacity = 0
        view.layer.masksToBounds = true
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        view.addGestureRecognizer(focusCursorTapGes)
        
        let pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchToAdjustCameraFocus(_:)))
        view.addGestureRecognizer(pinchGes)
    }
    
    private func observerDeviceMotion() {
        if !Thread.isMainThread {
            ZLMainAsync {
                self.observerDeviceMotion()
            }
            return
        }
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 0.5
        
        if motionManager?.isDeviceMotionAvailable == true {
            motionManager?.startDeviceMotionUpdates(to: .main, withHandler: { motion, _ in
                if let motion = motion {
                    self.handleDeviceMotion(motion)
                }
            })
        } else {
            motionManager = nil
        }
    }
    
    func handleDeviceMotion(_ motion: CMDeviceMotion) {
        let x = motion.gravity.x
        let y = motion.gravity.y
        
        if abs(y) >= abs(x) || abs(x) < 0.45 {
            if y >= 0.45 {
                orientation = .portraitUpsideDown
            } else {
                orientation = .portrait
            }
        } else {
            if x >= 0 {
                orientation = .landscapeLeft
            } else {
                orientation = .landscapeRight
            }
        }
    }
    
    private func setupCamera() {
        let cameraConfig = ZLPhotoConfiguration.default().cameraConfiguration
        
        guard let camera = getCamera(position: cameraConfig.devicePosition.avDevicePosition) else { return }
        guard let input = try? AVCaptureDeviceInput(device: camera) else { return }
        
        session.beginConfiguration()
        
        // 相机画面输入流
        videoInput = input
        
        refreshSessionPreset(device: camera)
        
        let movieFileOutput = AVCaptureMovieFileOutput()
        // 解决视频录制超过10s没有声音的bug
        movieFileOutput.movieFragmentInterval = .invalid
        self.movieFileOutput = movieFileOutput
        
        // 添加视频输入
        if let videoInput = videoInput, session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        // 添加音频输入
        addAudioInput()
        
        // 照片输出流
        let imageOutput = AVCapturePhotoOutput()
        self.imageOutput = imageOutput
        // 将输出流添加到session
        if session.canAddOutput(imageOutput) {
            session.addOutput(imageOutput)
        }
        if session.canAddOutput(movieFileOutput) {
            session.addOutput(movieFileOutput)
        }
        
        // imageOutPut添加到session之后才能判断supportedFlashModes
        if !cameraConfig.showFlashSwitch || torchDevice?.hasFlash == false {
            ZLMainAsync {
                self.showFlashBtn = false
            }
        }
        
        session.commitConfiguration()
        
        cameraConfigureFinish = true
        
        sessionQueue.async {
            self.setInitialZoomFactor(for: camera)
            self.session.startRunning()
        }
    }

    private func setInitialZoomFactor(for device: AVCaptureDevice) {
        guard isWideCameraEnabled() else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = device.zl.defaultZoomFactor
            device.unlockForConfiguration()
        } catch {
            zl_debugPrint("Failed to set initial zoom factor: \(error.localizedDescription)")
        }
    }
    
    private func findFirstDevice(ofTypes types: [AVCaptureDevice.DeviceType], in session: AVCaptureDevice.DiscoverySession) -> AVCaptureDevice? {
        for type in types {
            if let device = session.devices.first(where: { $0.deviceType == type }) {
                return device
            }
        }
        return nil
    }
    
    private func refreshSessionPreset(device: AVCaptureDevice) {
        func setSessionPreset(_ preset: AVCaptureSession.Preset) {
            guard session.sessionPreset != preset else {
                return
            }
            
            session.sessionPreset = preset
        }
        
        let preset = cameraConfig.sessionPreset.avSessionPreset
        if device.supportsSessionPreset(preset), session.canSetSessionPreset(preset) {
            setSessionPreset(preset)
        } else {
            setSessionPreset(.photo)
        }
    }
    
    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        var extendedDeviceTypes: [AVCaptureDevice.DeviceType] = []
        let allDeviceTypes: [AVCaptureDevice.DeviceType]
        
        if #available(iOS 13.0, *), cameraConfig.enableWideCameras {
            extendedDeviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera]
            allDeviceTypes = deviceTypes + extendedDeviceTypes
        } else {
            allDeviceTypes = deviceTypes
        }

        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: allDeviceTypes,
            mediaType: .video,
            position: position
        )

        if isWideCameraEnabled() {
            if let camera = findFirstDevice(ofTypes: extendedDeviceTypes, in: session) {
                torchDevice = camera
                return camera
            }
        }

        for device in session.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    private func getMicrophone() -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified).devices.first
    }
    
    private func addAudioInput() {
        guard cameraConfig.allowRecordVideo else { return }
        
        // 音频输入流
        var audioInput: AVCaptureDeviceInput?
        if let microphone = getMicrophone() {
            audioInput = try? AVCaptureDeviceInput(device: microphone)
        }
        
        guard microPhontIsAvailable, let ai = audioInput else { return }
        
        removeAudioInput()
        
        if session.isRunning {
            session.beginConfiguration()
        }
        if session.canAddInput(ai) {
            session.addInput(ai)
        }
        if session.isRunning {
            session.commitConfiguration()
        }
    }
    
    private func removeAudioInput() {
        var audioInput: AVCaptureInput?
        for input in session.inputs {
            if (input as? AVCaptureDeviceInput)?.device.deviceType == .builtInMicrophone {
                audioInput = input
            }
        }
        guard let audioInput = audioInput else { return }
        
        if session.isRunning {
            session.beginConfiguration()
        }
        session.removeInput(audioInput)
        if session.isRunning {
            session.commitConfiguration()
        }
    }
    
    private func addNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        if cameraConfig.allowRecordVideo {
            NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleAudioSessionInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        }
    }
    
    private func shownoMicrophoneAuthorityAlertMessageAlert() {
        let continueAction = ZLCustomAlertAction(title: localLanguageTextValue(.keepRecording), style: .default, handler: nil)
        let gotoSettingsAction = ZLCustomAlertAction(title: localLanguageTextValue(.gotoSettings), style: .tint) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        showAlertController(title: nil, message: String(format: localLanguageTextValue(.noMicrophoneAuthorityAlertMessage), getAppName()), style: .alert, actions: [continueAction, gotoSettingsAction], sender: self)
    }
    
    private func showAlertAndDismissAfterDoneAction(message: String, type: ZLNoAuthorityType?) {
        if let type, let customAlertWhenNoAuthority = ZLPhotoConfiguration.default().customAlertWhenNoAuthority {
            customAlertWhenNoAuthority(type)
            return
        }
        
        let action = ZLCustomAlertAction(title: localLanguageTextValue(.done), style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
                if let type {
                    ZLPhotoConfiguration.default().noAuthorityCallback?(type)
                }
            }
        }
        showAlertController(title: nil, message: message, style: .alert, actions: [action], sender: self)
    }
    
    private func cameraUsageTipsText() -> String {
        if cameraConfig.allowTakePhoto, cameraConfig.allowRecordVideo {
            return localLanguageTextValue(.customCameraTips)
        } else if cameraConfig.allowTakePhoto {
            return localLanguageTextValue(.customCameraTakePhotoTips)
        } else if cameraConfig.allowRecordVideo {
            if shouldUseTapToRecord {
                return localLanguageTextValue(.customCameraTapToRecordVideoTips)
            }
            
            return localLanguageTextValue(.customCameraRecordVideoTips)
        } else {
            return ""
        }
    }
    
    private func showTipsLabel(message: String, animated: Bool = true) {
        tipsLabel.layer.removeAllAnimations()
        tipsLabel.text = message
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.tipsLabel.alpha = 1
            }
        } else {
            tipsLabel.alpha = 1
        }
        startHideTipsLabelTimer()
    }
    
    private func hideTipsLabel(animated: Bool = true) {
        tipsLabel.layer.removeAllAnimations()
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.tipsLabel.alpha = 0
            }
        } else {
            tipsLabel.alpha = 0
        }
    }
    
    @objc private func hideTipsLabel_timerFunc() {
        cleanTimer()
        hideTipsLabel()
    }

    @objc private func autoStopRecording_timerFunc() {
        if movieFileOutput?.isRecording == true {
            finishRecord()
        }
    }

    private func startHideTipsLabelTimer() {
        cleanTimer()
        hideTipsTimer = Timer.scheduledTimer(timeInterval: 3, target: ZLWeakProxy(target: self), selector: #selector(hideTipsLabel_timerFunc), userInfo: nil, repeats: false)
        RunLoop.current.add(hideTipsTimer!, forMode: .common)
    }
    
    private func cleanTimer() {
        hideTipsTimer?.invalidate()
        hideTipsTimer = nil
    }
    
    private func cleanAutoStopTimer() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
    }

    @objc private func appWillResignActive() {
        if session.isRunning {
            dismiss(animated: true, completion: nil)
        }
        if videoURL != nil, let player = recordVideoPlayerLayer?.player {
            player.pause()
        }
    }
    
    @objc private func appDidBecomeActive() {
        if videoURL != nil, let player = recordVideoPlayerLayer?.player {
            player.play()
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notify: Notification) {
        guard recordVideoPlayerLayer?.isHidden == false, let player = recordVideoPlayerLayer?.player else {
            return
        }
        guard player.rate == 0 else {
            return
        }
        
        let type = notify.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        let option = notify.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
        if type == AVAudioSession.InterruptionType.ended.rawValue, option == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
            player.play()
        }
    }
    
    @objc private func dismissBtnClick() {
        cleanAutoStopTimer()
        dismiss(animated: true) {
            self.cancelBlock?()
        }
    }
    
    @objc private func retakeBtnClick() {
        sessionQueue.async {
            self.session.startRunning()
            self.resetSubViewStatus()
        }
        takedImage = nil
        stopRecordAnimation()
        cameraConfig.overlayView?.isHidden = false
        if let videoURL = videoURL {
            recordVideoPlayerLayer?.player?.pause()
            recordVideoPlayerLayer?.player = nil
            recordVideoPlayerLayer?.isHidden = true
            self.videoURL = nil
            try? FileManager.default.removeItem(at: videoURL)
        }
    }
    
    @objc private func flashBtnClick() {
        flashBtn.isSelected.toggle()
    }
    
    @objc private func switchCameraBtnClick() {
        guard !restartRecordAfterSwitchCamera, !isSwitchingCamera else {
            return
        }
        
        guard let videoInput, let movieFileOutput else {
            return
        }
        
        if movieFileOutput.isRecording {
            let pauseTime = animateLayer.convertTime(CACurrentMediaTime(), from: nil)
            animateLayer.speed = 0
            animateLayer.timeOffset = pauseTime
            restartRecordAfterSwitchCamera = true
        }
        
        isSwitchingCamera = true
        sessionQueue.async {
            do {
                defer {
                    self.isSwitchingCamera = false
                }
                
                let currInput = videoInput
                
                var newVideoInput: AVCaptureDeviceInput?
                if currInput.device.position == .back, let front = self.getCamera(position: .front) {
                    newVideoInput = try AVCaptureDeviceInput(device: front)
                } else if currInput.device.position == .front, let back = self.getCamera(position: .back) {
                    newVideoInput = try AVCaptureDeviceInput(device: back)
                } else {
                    return
                }
                
                if let newVideoInput {
                    self.session.beginConfiguration()
                    
                    self.refreshSessionPreset(device: newVideoInput.device)
                    
                    self.session.removeInput(currInput)
                    
                    if self.session.canAddInput(newVideoInput) {
                        self.session.addInput(newVideoInput)
                        self.videoInput = newVideoInput
                    } else {
                        self.refreshSessionPreset(device: currInput.device)
                        self.session.addInput(currInput)
                    }
                    
                    self.setInitialZoomFactor(for: newVideoInput.device)
                    self.session.commitConfiguration()
                }
            } catch {
                zl_debugPrint("切换摄像头失败 \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func editImage() {
        guard let takedImage = takedImage, canEditImage else {
            return
        }
        
        let isShowContinue = takedImages.count < self.takedCount - 1
        ZLEditImageViewController.showEditImageVC(parentVC: self, image: takedImage, isShowContinue: isShowContinue) { [weak self] in
            self?.retakeBtnClick()
        } continueTakingBlock: { [weak self] editImage, _ in
            self?.takedImages.append(editImage)
            self?.retakeBtnClick()
        } completion: { [weak self] editImage, _ in
            self?.takedImages.append(editImage)
            self?.takedImage = editImage
            self?.takedImageView.image = editImage
            self?.doneBtnClick()
        }
    }
    
    @objc private func doneBtnClick() {
        recordVideoPlayerLayer?.player?.pause()
        // 置为nil会导致卡顿，先注释，不影响内存释放
//        self.recordVideoPlayerLayer?.player = nil
        dismiss(animated: true) {
            if self.takedCount == 1 {
                self.takeDoneBlock?(self.takedImage, self.videoURL)
            } else {
                self.takesDoneBlock?(self.takedImages, self.videoURL)
            }
        }
    }
    
    // 点击拍照
    @objc private func takePicture() {
        if let willCaptureBlock = willCaptureBlock {
            guard !isCapturePending else { return }
            isCapturePending = true
            
            willCaptureBlock({ [weak self] in
                self?.performPhotoCapture()
            }, isTakingPicture)
        } else {
            performPhotoCapture()
        }
    }
    
    private func performPhotoCapture() {
        guard ZLPhotoManager.hasCameraAuthority(), !isTakingPicture else {
            return
        }
        guard let imageOutput = imageOutput else {
            return
        }
        guard session.outputs.contains(imageOutput) else {
            showAlertAndDismissAfterDoneAction(message: localLanguageTextValue(.cameraUnavailable), type: .camera)
            return
        }
        
        isTakingPicture = true
        
        let connection = imageOutput.connection(with: .video)
        connection?.videoOrientation = cameraConfig.lockedOutputOrientation ?? orientation
        if videoInput?.device.position == .front, connection?.isVideoMirroringSupported == true {
            connection?.isVideoMirrored = ZLPhotoConfiguration.default().cameraConfiguration.isVideoMirrored
        }
        
        let settingFormat: [String: Any]
        if #available(iOS 11.0, *) {
            settingFormat = [AVVideoCodecKey: AVVideoCodecType.jpeg]
        } else {
            settingFormat = [AVVideoCodecKey: AVVideoCodecJPEG]
        }
        let setting = AVCapturePhotoSettings(format: settingFormat)
        if videoInput?.device.hasFlash == true, flashBtn.isSelected {
            setting.flashMode = .on
        } else {
            setting.flashMode = .off
        }
        
        imageOutput.capturePhoto(with: setting, delegate: self)
    }
    
    // 长按录像
    @objc private func longPressAction(_ longGes: UILongPressGestureRecognizer) {
        if longGes.state == .began {
            guard ZLPhotoManager.hasCameraAuthority() else {
                return
            }
            startRecord()
        } else if longGes.state == .cancelled || longGes.state == .ended {
            finishRecord()
        }
    }
    
    @objc private func tapToRecordAction(_ tap: UITapGestureRecognizer) {
        movieFileOutput?.isRecording == true ? finishRecord() : startRecord(shouldScheduleStop: true)
    }
    
    // 调整焦点
    @objc private func adjustFocusPoint(_ tap: UITapGestureRecognizer) {
        guard session.isRunning, !isAdjustingFocusPoint else {
            return
        }
        let point = tap.location(in: view)
        if point.y > bottomView.frame.minY - 30 {
            return
        }
        setFocusCusor(point: point)
    }
    
    private func setFocusCusor(point: CGPoint) {
        animateFocusCursor(point: point)
        
        // UI坐标转换为摄像头坐标
        let cameraPoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: point) ?? view.center
        focusCamera(
            mode: ZLPhotoConfiguration.default().cameraConfiguration.focusMode.avFocusMode,
            exposureMode: ZLPhotoConfiguration.default().cameraConfiguration.exposureMode.avFocusMode,
            point: cameraPoint
        )
    }
    
    private func animateFocusCursor(point: CGPoint) {
        isAdjustingFocusPoint = true
        focusCursorView.center = point
        focusCursorView.alpha = 1
        
        let scaleAnimation = ZLAnimationUtils.animation(type: .scale, fromValue: 2, toValue: 1, duration: 0.25)
        let fadeShowAnimation = ZLAnimationUtils.animation(type: .fade, fromValue: 0, toValue: 1, duration: 0.25)
        let fadeDismissAnimation = ZLAnimationUtils.animation(type: .fade, fromValue: 1, toValue: 0, duration: 0.25)
        fadeDismissAnimation.beginTime = 0.75
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, fadeShowAnimation, fadeDismissAnimation]
        group.duration = 1
        group.delegate = self
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        focusCursorView.layer.add(group, forKey: nil)
    }
    
    // 调整焦距
    @objc private func adjustCameraFocus(_ pan: UIPanGestureRecognizer) {
        let convertRect = bottomView.convert(largeCircleView.frame, to: view)
        let point = pan.location(in: view)
        
        if pan.state == .began {
            dragStart = true
            startRecord()
        } else if pan.state == .changed {
            guard dragStart else {
                return
            }
            let maxZoomFactor = getMaxZoomFactor()
            var zoomFactor = (convertRect.midY - point.y) / convertRect.midY * maxZoomFactor
            zoomFactor = max(1, min(zoomFactor, maxZoomFactor))
            setVideoZoomFactor(zoomFactor)
        } else if pan.state == .cancelled || pan.state == .ended {
            guard dragStart else {
                return
            }
            dragStart = false
            finishRecord()
        }
    }
    
    @objc private func pinchToAdjustCameraFocus(_ pinch: UIPinchGestureRecognizer) {
        guard let device = videoInput?.device else {
            return
        }
        
        var zoomFactor = device.videoZoomFactor * pinch.scale
        zoomFactor = max(1, min(zoomFactor, getMaxZoomFactor()))
        setVideoZoomFactor(zoomFactor)
        
        pinch.scale = 1
    }
    
    private func isWideCameraEnabled() -> Bool {
        if #available(iOS 13.0, *) {
            return cameraConfig.enableWideCameras
        } else {
            return false
        }
    }
    
    private func getMaxZoomFactor() -> CGFloat {
        guard let device = videoInput?.device else {
            return 1
        }
        if #available(iOS 11.0, *) {
            let factor = isWideCameraEnabled() ? device.zl.defaultZoomFactor : 1
            return min(15 * factor, device.maxAvailableVideoZoomFactor)
        } else {
            return min(15, device.activeFormat.videoMaxZoomFactor)
        }
    }
    
    private func setVideoZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = videoInput?.device else {
            return
        }
        do {
            try device.lockForConfiguration()
            if #available(iOS 11.0, *), isWideCameraEnabled() {
                let minZoomFactor = device.minAvailableVideoZoomFactor
                let clampedZoomFactor = max(minZoomFactor, min(zoomFactor, getMaxZoomFactor()))
                device.videoZoomFactor = clampedZoomFactor
            } else {
                device.videoZoomFactor = zoomFactor
            }
            device.unlockForConfiguration()
        } catch {
            zl_debugPrint("调整焦距失败 \(error.localizedDescription)")
        }
    }
    
    private func focusCamera(mode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, point: CGPoint) {
        do {
            guard let device = videoInput?.device else {
                return
            }
            
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(mode) {
                device.focusMode = mode
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
            }
            if device.isExposureModeSupported(exposureMode) {
                device.exposureMode = exposureMode
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
            }
            
            device.unlockForConfiguration()
        } catch {
            zl_debugPrint("相机聚焦设置失败 \(error.localizedDescription)")
        }
    }
    
    // 打开手电筒
    private func openTorch() {
        guard flashBtn.isSelected,
              torchDevice?.isTorchAvailable == true,
              torchDevice?.torchMode == .off else {
            return
        }
        
        sessionQueue.async {
            do {
                try self.torchDevice?.lockForConfiguration()
                self.torchDevice?.torchMode = .on
                self.torchDevice?.unlockForConfiguration()
            } catch {
                zl_debugPrint("打开手电筒失败 \(error.localizedDescription)")
            }
        }
    }
    
    // 关闭手电筒
    private func closeTorch() {
        guard flashBtn.isSelected,
              torchDevice?.isTorchAvailable == true,
              torchDevice?.torchMode == .on else {
            return
        }
        
        sessionQueue.async {
            do {
                try self.torchDevice?.lockForConfiguration()
                self.torchDevice?.torchMode = .off
                self.torchDevice?.unlockForConfiguration()
            } catch {
                zl_debugPrint("关闭手电筒失败 \(error.localizedDescription)")
            }
        }
    }
    
    private func startRecord(shouldScheduleStop: Bool = false) {
        if let willCaptureBlock = willCaptureBlock {
            guard !isCapturePending else { return }
            isCapturePending = true
            // Pass information about current capture state.
            let isCapturing = movieFileOutput?.isRecording == true || restartRecordAfterSwitchCamera
            willCaptureBlock({ [weak self] in
                self?.startRecording(shouldScheduleStop: shouldScheduleStop)
                self?.isCapturePending = false
            }, isCapturing)
        } else {
            startRecording(shouldScheduleStop: shouldScheduleStop)
        }
    }
    
    private func startRecording(shouldScheduleStop: Bool = false) {
        guard let movieFileOutput = movieFileOutput else {
            return
        }
        
        guard !movieFileOutput.isRecording else {
            return
        }
        
        guard session.outputs.contains(movieFileOutput) else {
            showAlertAndDismissAfterDoneAction(message: localLanguageTextValue(.cameraUnavailable), type: .camera)
            return
        }
        
        dismissBtn.isHidden = true
        flashBtn.isHidden = true
        
        let connection = movieFileOutput.connection(with: .video)
        connection?.videoScaleAndCropFactor = 1
        if !restartRecordAfterSwitchCamera {
            let setOrientation = cameraConfig.lockedOutputOrientation ?? orientation
            connection?.videoOrientation = setOrientation
            cacheVideoOrientation = setOrientation
        } else {
            connection?.videoOrientation = cacheVideoOrientation
        }
        
        if let connection = connection, connection.isVideoStabilizationSupported, videoInput?.device.position == .back {
            connection.preferredVideoStabilizationMode = cameraConfig.videoStabilizationMode
        }
        
        // 解决不同系统版本,因为录制视频编码导致安卓端无法播放的问题
        if #available(iOS 11.0, *),
           movieFileOutput.availableVideoCodecTypes.contains(cameraConfig.videoCodecType),
           let connection = connection {
            let outputSettings = [AVVideoCodecKey: cameraConfig.videoCodecType]
            movieFileOutput.setOutputSettings(outputSettings, for: connection)
        }
        // 解决前置摄像头录制视频时候左右颠倒的问题
        if videoInput?.device.position == .front {
            // 镜像设置
            if connection?.isVideoMirroringSupported == true {
                connection?.isVideoMirrored = ZLPhotoConfiguration.default().cameraConfiguration.isVideoMirrored
            }
            closeTorch()
        } else {
            openTorch()
        }
        
        let url = URL(fileURLWithPath: ZLVideoManager.getVideoExportFilePath())
        movieFileOutput.startRecording(to: url, recordingDelegate: self)
        
        if shouldScheduleStop {
            cleanAutoStopTimer() // Cancel any existing timer.
            autoStopTimer = Timer.scheduledTimer(
                timeInterval: Double(cameraConfig.maxRecordDuration),
                target: ZLWeakProxy(target: self),
                selector: #selector(autoStopRecording_timerFunc),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    private func finishRecord() {
        closeTorch()
        restartRecordAfterSwitchCamera = false
        
        guard let movieFileOutput = movieFileOutput else {
            return
        }

        guard movieFileOutput.isRecording else {
            return
        }
        
        movieFileOutput.stopRecording()
    }
    
    private func startRecordAnimation() {
        UIView.animate(withDuration: 0.1, animations: {
            self.largeCircleView.layer.transform = CATransform3DScale(CATransform3DIdentity, ZLCustomCamera.Layout.largeCircleRecordScale, ZLCustomCamera.Layout.largeCircleRecordScale, 1)
            self.smallCircleView.layer.transform = CATransform3DScale(CATransform3DIdentity, ZLCustomCamera.Layout.smallCircleRecordScale, ZLCustomCamera.Layout.smallCircleRecordScale, 1)
            self.borderLayer.strokeColor = ZLCustomCamera.Layout.cameraBtnRecodingBorderColor.cgColor
            self.borderLayer.lineWidth = ZLCustomCamera.Layout.animateLayerWidth
            if self.shouldUseTapToRecord {
                self.smallCircleView.backgroundColor = .red
            }
        }) { _ in
            self.largeCircleView.layer.addSublayer(self.animateLayer)
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = Double(self.cameraConfig.maxRecordDuration)
            animation.delegate = self
            self.animateLayer.add(animation, forKey: nil)
        }
    }
    
    private func stopRecordAnimation() {
        ZLMainAsync {
            self.smallCircleView.backgroundColor = ZLCustomCamera.Layout.cameraBtnNormalColor
            self.borderLayer.strokeColor = ZLCustomCamera.Layout.cameraBtnNormalColor.cgColor
            self.borderLayer.lineWidth = ZLCustomCamera.Layout.borderLayerWidth
            self.animateLayer.speed = 1
            self.animateLayer.timeOffset = 0
            self.animateLayer.beginTime = 0
            self.animateLayer.removeFromSuperlayer()
            self.animateLayer.removeAllAnimations()
            self.largeCircleView.transform = .identity
            self.smallCircleView.transform = .identity
        }
    }
    
    private func resetSubViewStatus() {
        ZLMainAsync {
            if self.session.isRunning {
                self.showTipsLabel(message: self.cameraUsageTipsText())
                self.bottomView.isHidden = false
                self.dismissBtn.isHidden = false
                self.flashBtn.isHidden = !self.showFlashBtn
                self.retakeBtn.isHidden = true
                self.doneBtn.isHidden = true
                self.takedImageView.isHidden = true
                self.takedImage = nil
            } else {
                self.hideTipsLabel()
                self.bottomView.isHidden = true
                self.dismissBtn.isHidden = true
                if self.takedImage != nil {
                    self.retakeBtn.isHidden = self.canEditImage
                    self.doneBtn.isHidden = self.canEditImage
                } else {
                    self.retakeBtn.isHidden = false
                    self.doneBtn.isHidden = false
                }
            }
        }
    }
    
    private func playRecordVideo(fileURL: URL) {
        recordVideoPlayerLayer?.isHidden = false
        cameraConfig.overlayView?.isHidden = true
        let player = AVPlayer(url: fileURL)
        player.automaticallyWaitsToMinimizeStalling = false
        recordVideoPlayerLayer?.player = player
        player.play()
    }
    
    @objc private func recordVideoPlayFinished() {
        recordVideoPlayerLayer?.player?.seek(to: .zero)
        recordVideoPlayerLayer?.player?.play()
    }
}

extension ZLCustomCamera: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        ZLMainAsync {
            let animation = ZLAnimationUtils.animation(type: .fade, fromValue: 0, toValue: 1, duration: 0.25)
            self.previewLayer?.add(animation, forKey: nil)
        }
    }
    
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        handlePhotoOutputData(photo.fileDataRepresentation(), isError: error != nil)
    }
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
        previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        bracketSettings: AVCaptureBracketedStillImageSettings?,
        error: Error?
    ) {
        var data: Data?
        if let photoSampleBuffer {
            data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        }
        handlePhotoOutputData(data, isError: photoSampleBuffer == nil || error != nil)
    }
    
    private func handlePhotoOutputData(_ data: Data?, isError: Bool) {
        ZLMainAsync {
            defer {
                self.isTakingPicture = false
                self.isCapturePending = false
            }
            
            guard let data, !isError else {
                zl_debugPrint("take photo failed")
                return
            }
            
            self.cameraConfig.overlayView?.isHidden = true
            
            self.sessionQueue.async {
                self.session.stopRunning()
                self.resetSubViewStatus()
            }
            self.takedImage = UIImage(data: data)?.zl.fixOrientation()
            self.takedImageView.image = self.takedImage
            self.takedImageView.isHidden = false
            self.editImage()
        }
    }
}

extension ZLCustomCamera: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        /*
         recordLongGes?.state != .possible这个判断是为了防止在按钮上快速拖拽一下，然后手指马上离开
         此时在adjustCameraFocus方法中已经触发了开始录制，然后在该方法回调前手势结束又触发了停止录制。 这时候要在这里调用finishRecord
         */
        guard recordLongGes?.state != .possible || dragStart else {
            finishRecord()
            return
        }
        
        if restartRecordAfterSwitchCamera {
            restartRecordAfterSwitchCamera = false
            ZLMainAsync {
                let pauseTime = self.animateLayer.timeOffset
                self.animateLayer.speed = 1
                self.animateLayer.timeOffset = 0
                self.animateLayer.beginTime = 0
                let timeSincePause = self.animateLayer.convertTime(CACurrentMediaTime(), from: nil) - pauseTime
                self.animateLayer.beginTime = timeSincePause
            }
        } else {
            ZLMainAsync {
                self.startRecordAnimation()
            }
        }
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        ZLMainAsync {
            self.recordURLs.append(outputFileURL)
            self.recordDurations.append(output.recordedDuration.seconds)
            
            if self.restartRecordAfterSwitchCamera {
                self.startRecord()
                return
            }
            
            self.finishRecordAndMergeVideo()
        }
    }
    
    private func finishRecordAndMergeVideo() {
        ZLMainAsync {
            self.stopRecordAnimation()
            self.cleanAutoStopTimer() // Cancel timer when recording finishes.
            
            defer {
                self.resetSubViewStatus()
            }
            
            guard !self.recordURLs.isEmpty else {
                return
            }
            
            let duration = self.recordDurations.reduce(0, +)
            
            // 重置焦距
            self.setVideoZoomFactor(self.isWideCameraEnabled() ? (self.videoInput?.device.zl.defaultZoomFactor ?? 1) : 1)
            if duration < Double(self.cameraConfig.minRecordDuration) {
                showAlertView(String(format: localLanguageTextValue(.minRecordTimeTips), self.cameraConfig.minRecordDuration), self)
                self.recordURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                self.recordURLs.removeAll()
                self.recordDurations.removeAll()
                return
            }
            
            self.session.stopRunning()
            
            // 拼接视频
            if self.recordURLs.count > 1 {
                let hud = ZLProgressHUD.show(toast: .processing)
                ZLVideoManager.mergeVideos(fileURLs: self.recordURLs) { [weak self] url, error in
                    hud.hide()
                    
                    if let url = url, error == nil {
                        self?.videoURL = url
                        self?.playRecordVideo(fileURL: url)
                    } else if let error = error {
                        self?.videoURL = nil
                        showAlertView(error.localizedDescription, self)
                    }

                    self?.recordURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                    self?.recordURLs.removeAll()
                    self?.recordDurations.removeAll()
                }
            } else {
                let url = self.recordURLs[0]
                self.videoURL = url
                self.playRecordVideo(fileURL: url)
                self.recordURLs.removeAll()
                self.recordDurations.removeAll()
            }
        }
    }
}

extension ZLCustomCamera: CAAnimationDelegate {
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if anim is CAAnimationGroup {
            focusCursorView.alpha = 0
            focusCursorView.layer.removeAllAnimations()
            isAdjustingFocusPoint = false
        } else {
            finishRecord()
        }
    }
}

extension ZLCustomCamera: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gesTuples: [(UIGestureRecognizer?, UIGestureRecognizer?)] = [(recordLongGes, cameraFocusPanGes), (recordLongGes, focusCursorTapGes), (cameraFocusPanGes, focusCursorTapGes)]
        
        let result = gesTuples.map { ges1, ges2 in
            (ges1 == gestureRecognizer && ges2 == otherGestureRecognizer) ||
                (ges2 == otherGestureRecognizer && ges1 == gestureRecognizer)
        }.filter { $0 == true }
        
        return !result.isEmpty
    }
}
