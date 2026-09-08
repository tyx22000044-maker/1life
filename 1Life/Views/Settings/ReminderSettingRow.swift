import SwiftUI

struct ReminderSettingRow: View {
    let icon: String
    let name: String
    @Binding var hour: Int
    @Binding var isEnabled: Bool

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: hour)) ?? .now },
            set: { hour = Calendar.current.component(.hour, from: $0) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FamilyUI.panelMutedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FamilyUI.panelBorder, lineWidth: 1)
                )
                .frame(width: FamilyUI.iconBoxSize, height: FamilyUI.iconBoxSize)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Text(isEnabled ? "提醒已开启" : "提醒关闭")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isEnabled {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(FamilyUI.accent)
            }
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(FamilyUI.accent)
        }
        .padding(.vertical, 4)
    }
}
