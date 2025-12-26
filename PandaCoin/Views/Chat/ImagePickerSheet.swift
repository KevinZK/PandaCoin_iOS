//
//  ImagePickerSheet.swift
//  PandaCoin
//
//  图片选择器 - 支持相机和相册
//

import SwiftUI
import PhotosUI

// MARK: - 图片来源选择 Sheet
struct ImageSourceSheet: View {
    @Binding var isPresented: Bool
    let onSelectCamera: () -> Void
    let onSelectPhotoLibrary: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            Text("选择图片来源")
                .font(AppFont.body(size: 14))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 16)
                .padding(.bottom, 20)
            
            // 选项
            HStack(spacing: 40) {
                // 拍照
                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSelectCamera()
                    }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.bambooGreen.opacity(0.1))
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.bambooGreen)
                        }
                        
                        Text("拍照")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(Theme.text)
                    }
                }
                
                // 相册
                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSelectPhotoLibrary()
                    }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.income.opacity(0.1))
                                .frame(width: 64, height: 64)
                            
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.income)
                        }
                        
                        Text("相册")
                            .font(AppFont.body(size: 14, weight: .medium))
                            .foregroundColor(Theme.text)
                    }
                }
            }
            .padding(.bottom, 24)
            
            Divider()
                .background(Theme.separator)
            
            // 取消按钮
            Button(action: {
                isPresented = false
            }) {
                Text("取消")
                    .font(AppFont.body(size: 16, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
}

// MARK: - 相机选择器
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    // 检查相机是否可用
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        // 检查相机是否可用
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // 如果相机不可用，返回一个提示视图控制器
            let alert = UIAlertController(
                title: "相机不可用",
                message: "此设备没有可用的相机",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                context.coordinator.parent.dismiss()
            })
            
            let vc = UIViewController()
            vc.view.backgroundColor = .clear
            DispatchQueue.main.async {
                vc.present(alert, animated: true)
            }
            return vc
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - 相册选择器 (iOS 14+)
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        
        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        self?.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

