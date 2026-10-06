// Working version-one Files theme interchange, named theme replacement and live
// appearance controls. Draft edits validate before SQLite commits; import failures
// preserve the current theme and duplicate names require explicit replacement.
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ThemeFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(bundle: ThemeBundle) throws { data = try JSONEncoder().encode(bundle) }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents, bytes.count <= 1_048_576 else { throw CompanionError("Theme file is missing or too large") }; data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
struct ThemeView: View {
    @EnvironmentObject private var presentation: PresentationStore
    @State private var importing = false
    @State private var exporting = false
    @State private var document: ThemeFile?
    private var name: String { presentation.drafts["theme.name"] ?? "" }
    @State private var duplicate: ThemeBundle?
    private var colorDrafts: [String:String] {
        get { presentation.colorDrafts }
        nonmutating set { presentation.colorDrafts = newValue }
    }
    var body: some View {
        Form {
            Section("Desktop palettes") {
                Picker("Palette",selection:Binding(get:{ presentation.theme.name },set:{ name in if let theme = ThemeBundle.presets.values.first(where:{ $0.name == name }) { var next = presentation.theme
                    next.name = theme.name; next.palette = theme.palette
                    presentation.apply(next); colorDrafts = [:] } })) {
                    ForEach(ThemeBundle.presets.values.sorted(by:{ $0.name < $1.name }),id:\.name) { Text($0.name).tag($0.name) }
                    if !ThemeBundle.presets.values.contains(where:{ $0.name == presentation.theme.name }) { Text(presentation.theme.name).tag(presentation.theme.name) }
                }
                ForEach(ThemeBundle.roles,id:\.self) { role in
                    HStack {
                        Circle().fill(presentation.theme.color(role)).frame(width:20,height:20)
                        TextField(role,text:Binding(get:{ colorDrafts[role] ?? presentation.theme.palette[role] ?? "" },set:{ colorDrafts[role] = $0 }))
                            .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel(role + " hex color")
                        Button("Apply") {
                            var next = presentation.theme; next.palette[role] = colorDrafts[role] ?? next.palette[role]; presentation.apply(next)
                        }.frame(minHeight:44)
                    }
                }
                Button("Reset to Forest") { presentation.apply(ThemeBundle.presets["forest"]!); colorDrafts = [:] }
            }.phoneSection()
            Section("Harmony generators") {
                ForEach(["Complementary","Analogous","Triadic","Split Complementary"],id:\.self) { mode in Button(mode) { harmony(mode) }.frame(minHeight:44) }
            }.phoneSection()
            Section("Typography and surfaces") {
                Picker("Font",selection:binding(\.typography.font)) { ForEach(["Monospace","Sans Serif","Serif"],id:\.self) { Text($0) } }
                Picker("Text size",selection:binding(\.typography.text_size)) { ForEach(["Small","Default","Large"],id:\.self) { Text($0) } }
                Picker("Density",selection:binding(\.typography.density)) { ForEach(["Compact","Comfortable","Roomy"],id:\.self) { Text($0) } }
                Toggle("Frosted panels",isOn:binding(\.typography.frosted))
                Text("Reduce Transparency uses opaque panels. Dynamic Type remains available at every text size.").font(.caption)
            }.phoneSection()
            Section("Background") {
                Picker("Effect",selection:binding(\.effect.name)) { ForEach(ThemeBundle.effects,id:\.self) { Text($0) } }
                slider("Speed",key:\.effect.speed,range:0.05...4)
                slider("Intensity",key:\.effect.intensity,range:0.05...4)
                slider("Size",key:\.effect.size,range:0.25...3)
                slider("Quality",key:\.effect.quality,range:0.25...2)
                TextField("Effect color (#RRGGBB)",text:Binding(get:{ colorDrafts["effect"] ?? presentation.theme.effect.color },set:{ colorDrafts["effect"] = $0 })).textInputAutocapitalization(.never)
                Button("Apply effect color") { var next = presentation.theme; next.effect.color = colorDrafts["effect"] ?? next.effect.color; presentation.apply(next) }
                Toggle("Paused",isOn:binding(\.effect.paused))
                Text("Phone target: 30 FPS. Reduce Motion, Low Power Mode and inactive scenes use a static presentation.").font(.caption)
            }.phoneSection()
            Section("Named themes and Files") {
                TextField("Theme name",text:presentation.draft("theme.name"))
                Button("Save named theme") { var next = presentation.theme; next.name = name; save(next) }
                ForEach(presentation.savedThemes.keys.sorted(),id:\.self) { key in Button(key) { if let bundle = presentation.savedThemes[key] { presentation.apply(bundle); colorDrafts = [:] } } }
                Button("Import theme") { importing = true }
                Button("Export current theme") {
                    do { document = try ThemeFile(bundle:presentation.theme); exporting = true } catch { presentation.error = error.localizedDescription }
                }
            }.phoneSection()
        }.navigationTitle("Theme")
            .onChange(of:importing) { _,value in presentation.opaquePresentation = value || exporting }
            .onChange(of:exporting) { _,value in presentation.opaquePresentation = value || importing }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
                do {
                    let url = try result.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys:[.fileSizeKey])
                    guard (values.fileSize ?? 0) <= 1_048_576 else { throw CompanionError("Theme file is too large") }
                    let next = try JSONDecoder().decode(ThemeBundle.self,from:Data(contentsOf:url)); try next.validate()
                    save(next)
                } catch { presentation.error = error.localizedDescription }
            }
            .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"Tinker-theme") { result in if case .failure(let error) = result { presentation.error = error.localizedDescription } }
            .confirmationDialog("Replace the saved theme named " + (duplicate?.name ?? "") + "?",isPresented:Binding(get:{ duplicate != nil },set:{ if !$0 { duplicate = nil } }),titleVisibility:.visible) {
                Button("Replace",role:.destructive) {
                    if let bundle = duplicate { do { try presentation.saveTheme(bundle,replacing:true); presentation.apply(bundle) } catch { presentation.error = error.localizedDescription } }; duplicate = nil
                }
            }
    }
    /// A single validated immutable update keeps every consumer on the same theme.
    private func binding<T>(_ path: WritableKeyPath<ThemeBundle,T>) -> Binding<T> {
        Binding(get:{ presentation.theme[keyPath:path] },set:{ value in var next = presentation.theme; next[keyPath:path] = value; presentation.apply(next) })
    }
    private func slider(_ title: String,key: WritableKeyPath<ThemeBundle,Double>,range: ClosedRange<Double>) -> some View {
        VStack(alignment:.leading) { Text(title); Slider(value:binding(key),in:range).accessibilityLabel(title) }
    }
    private func save(_ bundle: ThemeBundle) {
        do {
            try bundle.validate()
            if presentation.savedThemes[bundle.name] != nil { duplicate = bundle; return }
            try presentation.saveTheme(bundle); presentation.apply(bundle)
        } catch { presentation.error = error.localizedDescription }
    }
    /// Port desktop HSV harmony relationships; retain the exact accent. Lightness
    /// determines the dark/light neutral range; generators never touch sync data.
    private func harmony(_ mode: String) {
        let color = UIColor(Color(hex:presentation.theme.palette["accent"] ?? "#67cf92"))
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h,saturation:&s,brightness:&v,alpha:&a)
        let offsets: [String:(CGFloat,CGFloat)] = ["Complementary":(0,0.5),"Analogous":(-0.075,0.075),"Triadic":(1/3,2/3),"Split Complementary":(0.42,0.58)]
        let pair = offsets[mode]!
        let bg = UIColor(presentation.theme.color("background")); var r: CGFloat = 0,g: CGFloat = 0,b: CGFloat = 0
        bg.getRed(&r,green:&g,blue:&b,alpha:&a)
        let dark = (r + g + b)/3 < 0.5
        let base: CGFloat = s < 0.000001 ? 0 : max(0.08,s * 0.28)
        let relation: CGFloat = s < 0.000001 ? 0 : max(0.16,s * 0.62)
        func hex(_ hue: CGFloat,_ sat: CGFloat,_ brightness: CGFloat) -> String {
            let c = UIColor(hue:(hue + 1).truncatingRemainder(dividingBy:1),saturation:sat,brightness:brightness,alpha:1)
            var red: CGFloat = 0,green: CGFloat = 0,blue: CGFloat = 0,alpha: CGFloat = 0
            c.getRed(&red,green:&green,blue:&blue,alpha:&alpha)
            return String(format:"#%02x%02x%02x",Int((red*255).rounded()),Int((green*255).rounded()),Int((blue*255).rounded()))
        }
        var next = presentation.theme
        next.palette["background"] = hex(h,dark ? base : base*0.5,dark ? 0.13 : 0.97)
        next.palette["panel"] = hex(h,dark ? base*0.9 : base*0.25,dark ? 0.19 : 1)
        next.palette["border"] = hex(h+pair.0,dark ? relation : relation*0.55,dark ? 0.4 : 0.76)
        next.palette["muted"] = hex(h+pair.1,dark ? relation*0.78 : relation*0.62,dark ? 0.62 : 0.49)
        next.palette["text"] = dark ? "#eef4f0" : "#20231f"
        next.palette["sidebar"] = next.palette["background"]; next.palette["input_bg"] = next.palette["panel"]
        next.palette["send_bg"] = next.palette["border"]
        presentation.apply(next); colorDrafts = [:]
    }
}
