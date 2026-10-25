import SwiftUI
import UIKit

struct GarmentCategoryPicker: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selection: String

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                picker.labelsHidden()
            }
        } else { picker }
    }

    private var picker: some View {
        Picker("Category", selection: $selection) {
            Text("Unknown").tag("")
            if !selection.isEmpty && !GarmentCategory.all.contains(selection) {
                Text(selection).tag(selection)
            }
            ForEach(GarmentCategory.groups) { group in
                Section(group.title) {
                    ForEach(group.categories, id: \.self) { Text($0).tag($0) }
                }
            }
        }
        .pickerStyle(.menu)
    }
}

struct GarmentColorOption: Identifiable {
    let id: String
    let rgb: UInt32
    var title: String { id.capitalized }
    var color: Color { Color(uiColor: UIColor(rgb: rgb)) }

    static let all = [
        Self(id: "black", rgb: 0x242424), Self(id: "white", rgb: 0xFFFFFF),
        Self(id: "gray", rgb: 0x90949C), Self(id: "beige", rgb: 0xD9C4A5),
        Self(id: "cream", rgb: 0xF6EDD5), Self(id: "brown", rgb: 0x80583C),
        Self(id: "red", rgb: 0xC94040), Self(id: "orange", rgb: 0xE78B3C),
        Self(id: "yellow", rgb: 0xEBC94C), Self(id: "green", rgb: 0x49875C),
        Self(id: "blue", rgb: 0x4B75B9), Self(id: "navy", rgb: 0x263A60),
        Self(id: "purple", rgb: 0x8B63B4), Self(id: "pink", rgb: 0xE7A0BC)
    ]

    var menuImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            let circle = CGRect(x: 2, y: 2, width: 16, height: 16)
            context.cgContext.setFillColor(UIColor(rgb: rgb).cgColor)
            context.cgContext.fillEllipse(in: circle)
            context.cgContext.setStrokeColor(UIColor.gray.withAlphaComponent(0.4).cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.strokeEllipse(in: circle)
        }.withRenderingMode(.alwaysOriginal)
    }
}

struct GarmentColorPicker: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var selection: Set<String>
    var editing = true

    var body: some View {
        if editing { menu } else { colorRow }
    }

    private var menu: some View {
        Menu {
            ForEach(GarmentColorOption.all) { option in
                Toggle(isOn: .init(
                    get: { selection.contains(option.id) },
                    set: { if $0 { selection.insert(option.id) } else { selection.remove(option.id) } }
                )) {
                    Label { Text(option.title) } icon: {
                        Image(uiImage: option.menuImage)
                    }
                }
            }
            if !selection.isEmpty {
                Divider()
                Button("Clear colors") { selection.removeAll() }
            }
        } label: { colorRow }
        .menuActionDismissBehavior(.disabled)
        .buttonStyle(.plain)
        .accessibilityLabel("Adjust colors")
        .accessibilityValue(selection.isEmpty ? "Unknown" : selection.sorted().map { $0.capitalized }.joined(separator: ", "))
        .accessibilityHint("Select one or more colors.")
    }

    private var colorRow: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Colors").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption).opacity(editing ? 1 : 0)
                    }
                    GarmentColorTags(colors: selection.sorted())
                }
            } else {
                HStack(alignment: .top) {
                    Text("Colors").foregroundStyle(.primary)
                    Spacer(minLength: 16)
                    GarmentColorTags(colors: selection.sorted())
                        .frame(maxWidth: 210, alignment: .trailing)
                    Image(systemName: "chevron.down").font(.caption).opacity(editing ? 1 : 0)
                }
            }
        }
    }
}

struct GarmentColorTags: View {
    let colors: [String]

    var body: some View {
        if colors.isEmpty {
            Text("Unknown").font(.subheadline).foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 14, maximum: 14), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(colors, id: \.self) { name in
                    Circle()
                        .fill(GarmentColorOption.all.first { $0.id == name }?.color ?? Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay { Circle().strokeBorder(Color.gray.opacity(0.4), lineWidth: 1) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(name) color")
                }
            }
        }
    }
}
