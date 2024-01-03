//
//  VolumeButtonManager.swift
//
//
//  Created by Luca Archidiacono on 13.11.2023.
//

import MediaPlayer

private struct Logger {
	enum Status: String {
		case error
		case info
	}

	private let system: String

	init(system: String) {
		self.system = system
	}

	func log(status: Status, _ message: String) {
		let message = "[\(system):\(status.rawValue.capitalized)] \(message)"
		NSLog("%@", message)
	}
}

/// Manages the device's volume buttons and updates the app's state accordingly.
public class VolumeButtonManager {
	private var audioSession = AVAudioSession.sharedInstance()
	private var volumeView = MPVolumeView(frame: CGRectMake(CGFloat(MAXFLOAT), CGFloat(MAXFLOAT), 0, 0))
	private var volumeObserver: NSKeyValueObservation?
	private var initialVolume: Float!
	private var isAdjustingInitialVolume = false
	private var isActive = true
	private var hasStarted = false

	private let maxVolume: Float = 0.99999
	private let minVolume: Float = 0.00001

	private let logger = Logger(system: #file)

	public var onAction: (() -> Void)?

	public init() {
		if !hasStarted {
			start()
		}
	}

	deinit {
		invalidate()
	}

	/// Starts the volume button manager, setting up observers and audio sessions.
	public func start() {
		if !hasStarted {
			hasStarted = true
			invalidate()
			observe()
			setupVolumeView()
			setupAudioSession()
			setupInitialVolume()
		}
	}

	/// Stops the volume button manager, removing evertything, from observers to audio sessions.
	public func stop() {
		if hasStarted {
			invalidate()
			hasStarted = false
		}
	}

	/// Sets up the initial volume level and adjusts it within specified bounds.
	private func setupInitialVolume() {
		initialVolume = audioSession.outputVolume
		if initialVolume > maxVolume {
			initialVolume = maxVolume
			isAdjustingInitialVolume = true
			setVolume(initialVolume)
		} else if initialVolume < minVolume {
			initialVolume = minVolume
			isAdjustingInitialVolume = true
			setVolume(initialVolume)
		}
	}

	/// Configures the audio session for playback, allowing mixing with other audio sources.
	private func setupAudioSession() {
		do {
			try audioSession.setActive(true)
			try audioSession.setCategory(AVAudioSession.Category.playback, options: .mixWithOthers)
		} catch {
			logger.log(status: .error, "Error setting up audio session: \(error)")
		}
	}

	/// Adds a hidden MPVolumeView to the window scene to manage volume changes.
	private func setupVolumeView() {
		let scene = UIApplication.shared.connectedScenes
			.filter { $0.activationState == .foregroundActive }
			.first { $0 is UIWindowScene }
			.flatMap { $0 as? UIWindowScene }?.windows
			.first(where: \.isKeyWindow)
		scene?.addSubview(volumeView)

		volumeView.isHidden = false
		volumeView.alpha = 0.01
	}

	/// Observes volume changes and triggers actions accordingly.
	private func observe() {
		/// Observes changes in the system output volume.
		/// - Note:
		///   This observer addresses the scenario where a user attempts to change the volume when it's already at its
		/// maximum (1.0) or minimum (0.0) level. Normally, trying to increase the volume when it's already at 1.0 or
		/// decrease it when at 0.0 does not trigger the observer, as the system detects no actual change in volume.
		///   To circumvent this, the class uses slightly lower than maximum (0.99999) and higher than minimum (0.00001)
		/// values as thresholds. Upon initialization, if the system volume is at 1.0, it's adjusted to 0.99999, and
		/// similarly, if it's at 0.0, it's adjusted to 0.00001. This ensures that subsequent volume changes, even when
		/// at these extremes, trigger the observer.
		///   This mechanism also helps in maintaining the original volume setting of the user. By initially adjusting
		/// the volume to a near-maximum or near-minimum value, the class can detect volume button presses without
		/// permanently altering the user's set volume level.
		volumeObserver = audioSession.observe(\.outputVolume, options: [
			.old,
			.new,
		]) { [weak self] _, observedValue in
			guard let self,
				  isActive,
				  let newValue = observedValue.newValue,
				  let oldValue = observedValue.oldValue
			else { return }

			let difference = abs(newValue - oldValue)

			if isAdjustingInitialVolume {
				isAdjustingInitialVolume = false
				return
			}

			logger.log(status: .info, "Old Volume: \(oldValue), New Volume: \(newValue), Difference = \(difference)")

			if (newValue == 1.0 && oldValue == 1.0) || (newValue == 0.0 && oldValue == 0.0) {
				onAction?()
				setupInitialVolume()
				return
			} else {
				onAction?()
				isAdjustingInitialVolume = true
				setVolume(initialVolume)
				return
			}
		}

		NotificationCenter.default.addObserver(self,
											   selector: #selector(audioSessionInterrupted),
											   name: AVAudioSession.interruptionNotification,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(applicationDidChangeActive),
											   name: UIApplication.willResignActiveNotification,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(applicationDidChangeActive),
											   name: UIApplication.didBecomeActiveNotification,
											   object: nil)
	}

	/// Called when the audio session is interrupted, handling various interruption types.
	@objc
	private func audioSessionInterrupted(notification: NSNotification) {
		if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
		   let reasonIntegerValue = userInfoValue.integerValue,
		   let reason = AVAudioSession.InterruptionType(rawValue: UInt(reasonIntegerValue)) {
			logger.log(status: .info, "Audio session was interrupted with reason \(reason)")

			switch reason {
			case .began:
				logger.log(status: .info, "Audio Session interruption has began.")
			case .ended:
				logger.log(status: .info, "Audio Session interruption has ended.")
				do {
					try audioSession.setActive(true)
				} catch {
					logger.log(status: .error, "\(error)")
				}
			@unknown default:
				logger.log(status: .error, "Not covered Audio Session interruption: \(reason)")
			}
		}
	}

	/// Handles changes in the application's active state, updating the audio session and volume.
	@objc
	private func applicationDidChangeActive(notification: NSNotification) {
		isActive = notification.name == UIApplication.didBecomeActiveNotification
		if isActive {
			// Foreground
			setupAudioSession()
			setupInitialVolume()
		}
	}

	/// Cleans up observers and removes the volume view from the view hierarchy.
	private func invalidate() {
		NotificationCenter.default.removeObserver(self)
		volumeObserver?.invalidate()
		volumeView.removeFromSuperview()
	}

	/// Sets the system volume to the specified level.
	private func setVolume(_ volume: Float) {
		for subview in volumeView.subviews {
			if let volumeSlider = subview as? UISlider {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
					volumeSlider.value = volume
				}
			}
		}
	}
}
