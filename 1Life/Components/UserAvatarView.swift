import SwiftUI

struct UserAvatarView: View {
    var avatarData: Data? = nil
    var symbolName: String = ""
    let name: String
    let size: CGFloat

    private var initials: String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let data = avatarData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Rectangle())
            } else if !symbolName.isEmpty {
                ZStack {
                    Rectangle()
                        .fill(FamilyUI.panelMutedBackground)
                        .frame(width: size, height: size)
                        .overlay(
                            Rectangle()
                                .stroke(FamilyUI.panelBorder, lineWidth: 1)
                        )
                    Image(systemName: symbolName)
                        .font(.system(size: size * 0.48))
                        .foregroundStyle(FamilyUI.ink)
                }
            } else if !name.isEmpty {
                Rectangle()
                    .fill(FamilyUI.ink)
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .font(.custom("Archivo-Bold", size: size * 0.35))
                            .foregroundStyle(FamilyUI.pageBackground)
                    )
            } else {
                Rectangle()
                    .fill(FamilyUI.panelMutedBackground)
                    .frame(width: size, height: size)
                    .overlay(
                        Rectangle()
                            .stroke(FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(FamilyUI.inkFaint)
                    )
            }
        }
        .accessibilityLabel(name.isEmpty ? "用户头像" : "\(name) 的头像")
    }
}
