import SwiftUI
import PhotosUI

struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: UserSettings
    @State private var nickname: String = ""
    @State private var avatarData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemPageHeader(
                        eyebrow: "资料编辑",
                        title: "编辑资料",
                        detail: "修改昵称、头像与个人资料"
                    )

                    SystemPanel(title: "头像", detail: "点击头像即可更换照片") {
                        HStack {
                            Spacer()
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    UserAvatarView(avatarData: avatarData, name: nickname, size: 108)
                                    Rectangle()
                                        .fill(FamilyUI.accent)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(FamilyUI.pageBackground)
                                        )
                                }
                            }
                            Spacer()
                        }
                    }

                    SystemPanel(title: "身份信息", detail: "昵称会用于设置页、日志等个人标识") {
                        SystemTextField(label: "昵称", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(FamilyUI.panelMutedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.pageBottom)
            }
            .background(FamilyUI.pageBackground.ignoresSafeArea())
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        settings.nickname = nickname.trimmingCharacters(in: .whitespaces)
                        settings.avatarImageData = avatarData
                        settings.updatedAt = .now
                        HapticEngine.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = settings.nickname
                avatarData = settings.avatarImageData
            }
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }
}
