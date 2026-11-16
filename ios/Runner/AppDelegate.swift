import Flutter
import Photos
import PhotosUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var hostChannel: FlutterMethodChannel?
  /// 选图 delegate 必须强引用，否则 present 期间就被释放，回调永远不来。
  private var pickerHandler: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "avatar.host",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "pickImage":
        self.pickImage(result: result)
      case "saveImage":
        self.saveImage(call: call, result: result)
      case "loadLocal":
        self.loadLocal(result: result)
      case "writeLocal":
        if let args = call.arguments as? [String: Any],
           let key = args["key"] as? String,
           let value = args["value"] as? String {
          UserDefaults.standard.set(value, forKey: Self.prefsPrefix + key)
        }
        result(nil)
      case "removeLocal":
        if let args = call.arguments as? [String: Any],
           let key = args["key"] as? String {
          UserDefaults.standard.removeObject(forKey: Self.prefsPrefix + key)
        }
        result(nil)
      case "exitApp":
        result(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          exit(0)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.hostChannel = channel
  }

  // MARK: - 本地存储

  private static let prefsPrefix = "avatar."

  private func loadLocal(result: @escaping FlutterResult) {
    var out: [String: String] = [:]
    for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
      guard key.hasPrefix(Self.prefsPrefix) else { continue }
      if let s = value as? String {
        out[String(key.dropFirst(Self.prefsPrefix.count))] = s
      }
    }
    result(out)
  }

  // MARK: - 选图

  private func pickImage(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let host = self.topViewController() else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "无法打开相册", details: nil))
        return
      }
      let onPicked: (Data?) -> Void = { [weak self] data in
        self?.pickerHandler = nil
        if let data = data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          // 用户取消：静默返回 null，与 Android / 鸿蒙行为一致
          result(nil)
        }
      }

      if #available(iOS 14.0, *) {
        let handler = ImagePickerHandler(completion: onPicked)
        self.pickerHandler = handler
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = handler
        host.present(picker, animated: true)
      } else {
        let handler = LegacyPickerHandler(completion: onPicked)
        self.pickerHandler = handler
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = handler
        host.present(picker, animated: true)
      }
    }
  }

  // MARK: - 保存到相册

  private func saveImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let typed = args["bytes"] as? FlutterStandardTypedData,
          let image = UIImage(data: typed.data) else {
      result(FlutterError(code: "BAD_ARGS", message: "图片数据无效", details: nil))
      return
    }
    PHPhotoLibrary.requestAuthorization { status in
      // .limited 是 iOS 14+ 才有的枚举值，低版本只认 .authorized
      var granted = (status == .authorized)
      if #available(iOS 14.0, *), status == .limited {
        granted = true
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NO_PERMISSION",
                              message: "未获得相册写入权限，请到「设置 → 隐私 → 照片」中允许",
                              details: nil))
        }
        return
      }
      PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      } completionHandler: { success, error in
        DispatchQueue.main.async {
          if success {
            result("已保存到相册")
          } else {
            result(FlutterError(code: "SAVE_FAILED",
                                message: error?.localizedDescription ?? "保存失败，请重试",
                                details: nil))
          }
        }
      }
    }
  }

  // MARK: - 顶层控制器

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    let keyWindow = windows.first(where: { $0.isKeyWindow }) ?? windows.first
    var vc = keyWindow?.rootViewController ?? self.window?.rootViewController
    while let presented = vc?.presentedViewController {
      vc = presented
    }
    return vc
  }
}

/// 同时兼容 PHPicker（iOS 14+）与 UIImagePickerController（iOS 13）。
/// 两条路各用一个 delegate 类，避免 iOS 13 部署目标下的 availability 冲突。
@available(iOS 14.0, *)
final class ImagePickerHandler: NSObject, PHPickerViewControllerDelegate {
  private let completion: (Data?) -> Void
  private var finished = false

  init(completion: @escaping (Data?) -> Void) {
    self.completion = completion
  }

  private func finish(_ data: Data?) {
    guard !finished else { return }
    finished = true
    DispatchQueue.main.async {
      self.completion(data)
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider,
          provider.hasItemConformingToTypeIdentifier("public.image") else {
      finish(nil)
      return
    }
    provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
      self.finish(data)
    }
  }
}

final class LegacyPickerHandler: NSObject,
                                 UIImagePickerControllerDelegate,
                                 UINavigationControllerDelegate {
  private let completion: (Data?) -> Void
  private var finished = false

  init(completion: @escaping (Data?) -> Void) {
    self.completion = completion
  }

  private func finish(_ data: Data?) {
    guard !finished else { return }
    finished = true
    DispatchQueue.main.async {
      self.completion(data)
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)
    if let image = info[.originalImage] as? UIImage, let data = image.pngData() {
      finish(data)
    } else {
      finish(nil)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    finish(nil)
  }
}
