import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import ImageIO

/// A single system picker at a time; completion is delivered once on the main queue.
final class NativePickers: NSObject, UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private var completion: ((Result<Any?, Error>) -> Void)?
    private var exporting: URL?
    private var limit = 1
    private let io = DispatchQueue(label: "app.leandaily.images", qos: .userInitiated)
    private var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var controller = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let next = controller?.presentedViewController { controller = next }
        return controller
    }
    private func reserve(_ done: @escaping (Result<Any?, Error>) -> Void) -> UIViewController? {
        guard completion == nil, let controller = presenter, !controller.isBeingDismissed else {
            done(.failure(NativeFailure("请先完成当前选择操作"))); return nil
        }
        completion = done
        return controller
    }
    private func finish(_ result: Result<Any?, Error>) {
        dispatchPrecondition(condition: .onQueue(.main))
        let done = completion; completion = nil
        if let file = exporting { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        exporting = nil
        done?(result)
    }
    func exportDocument(data: String, name: String, done: @escaping (Result<Any?, Error>) -> Void) {
        guard let controller = reserve(done) else { return }
        let bytes = Data(data.utf8)
        guard bytes.count <= 100 * 1024 * 1024 else { finish(.failure(NativeFailure("备份超过100MB，请减少照片后重试"))); return }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("leandaily-export-\(UUID())", isDirectory: true)
        let filename = (name as NSString).lastPathComponent
        let url = folder.appendingPathComponent(filename.isEmpty || filename == "." || filename == ".." ? "薄肌日课备份.json" : filename)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bytes.write(to: url, options: [.atomic, .completeFileProtection])
            exporting = url
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            picker.delegate = self; controller.present(picker, animated: true)
            picker.presentationController?.delegate = self
        } catch { try? FileManager.default.removeItem(at: folder); finish(.failure(error)) }
    }
    func importDocument(done: @escaping (Result<Any?, Error>) -> Void) {
        guard let controller = reserve(done) else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true)
        picker.allowsMultipleSelection = false; picker.delegate = self
        controller.present(picker, animated: true); picker.presentationController?.delegate = self
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(.failure(NativeFailure(exporting == nil ? "已取消导入" : "已取消导出")))
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if exporting != nil { finish(.success(nil)); return }
        guard let url = urls.first else { finish(.failure(NativeFailure("已取消导入"))); return }
        io.async {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let result: Result<Any?, Error> = Result {
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let bytes = try handle.read(upToCount: 100 * 1024 * 1024 + 1) ?? Data()
                guard bytes.count <= 100 * 1024 * 1024 else { throw NativeFailure("备份超过100MB") }
                guard let value = String(data: bytes, encoding: .utf8) else { throw NativeFailure("备份不是有效 UTF-8 文件") }
                return value
            }
            DispatchQueue.main.async { self.finish(result) }
        }
    }
    func pickImages(source: String, limit: Int, done: @escaping (Result<Any?, Error>) -> Void) {
        guard let controller = reserve(done) else { return }
        self.limit = min(8, max(1, limit))
        if source == "gallery" {
            var config = PHPickerConfiguration(); config.filter = .images
            config.selectionLimit = self.limit
            let picker = PHPickerViewController(configuration: config); picker.delegate = self
            controller.present(picker, animated: true); picker.presentationController?.delegate = self
        } else if source == "camera" {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                finish(.failure(NativeFailure("此设备无法使用相机，请选择相册（模拟器不支持拍照）"))); return
            }
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard granted else { self.finish(.failure(NativeFailure("相机权限未开启，请在系统设置里允许使用相机"))); return }
                    let picker = UIImagePickerController(); picker.sourceType = .camera
                    picker.cameraCaptureMode = .photo; picker.delegate = self
                    controller.present(picker, animated: true); picker.presentationController?.delegate = self
                }
            }
        } else { finish(.failure(NativeFailure("照片来源无效"))) }
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { finish(.success([Data]())); return }
        load(results.prefix(limit).map(\.itemProvider), index: 0, values: [])
    }
    private func load(_ providers: [NSItemProvider], index: Int, values: [Data]) {
        guard index < providers.count else {
            DispatchQueue.main.async { self.finish(.success(values)) }; return
        }
        providers[index].loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            do {
                if let error = error { throw error }
                guard let url = url else { throw NativeFailure("无法读取所选照片") }
                // The provider's URL is only valid during this callback. Downsample before it returns.
                let bytes = try autoreleasepool { try Self.jpeg(url) }
                self.load(providers, index: index + 1, values: values + [bytes])
            } catch { DispatchQueue.main.async { self.finish(.failure(error)) } }
        }
    }
    static func jpeg(_ url: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary), let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8),
              data.count <= 12 * 1024 * 1024 else { throw NativeFailure("无法处理照片，请选择其他图片") }
        return data
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true); finish(.success([Data]()))
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { finish(.failure(NativeFailure("无法读取拍摄照片"))); return }
        io.async {
            let result: Result<Any?, Error> = Result {
                try autoreleasepool {
                    let ratio = min(1, 1600 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                    let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                    guard let bytes = normalized.jpegData(compressionQuality: 0.8), bytes.count <= 12 * 1024 * 1024 else { throw NativeFailure("无法处理照片") }
                    return [bytes]
                }
            }
            DispatchQueue.main.async { self.finish(result) }
        }
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if presentationController.presentedViewController is PHPickerViewController || presentationController.presentedViewController is UIImagePickerController {
            finish(.success([Data]()))
        } else { finish(.failure(NativeFailure(exporting == nil ? "已取消导入" : "已取消导出"))) }
    }
}
