// Desktop version-one theme interchange and semantic palette ownership.
// PresentationStore persists these values outside synchronized domain graphs.
// Validation precedes every application/import; malformed values never replace
// the active theme. These exact palettes come from desktop core/theme.py at m1.
import SwiftUI

struct ThemeTypography: Codable, Equatable {
    var font = "Monospace"
    var text_size = "Default"
    var density = "Comfortable"
    var frosted = false
}
struct ThemeEffect: Codable, Equatable {
    var name = "Leaves"
    var color = "#67cf92"
    var speed = 1.0
    var intensity = 1.0
    var quality = 1.0
    var size = 1.0
    var paused = false
}
struct ThemeBundle: Codable, Equatable {
    var version = 1
    var name: String
    var palette: [String:String]
    var typography = ThemeTypography()
    var effect = ThemeEffect()
    static let roles = ["background","panel","sidebar","border","text","muted","accent","input_bg","send_bg"]
    static let effects = ["Solid","Dots","Synapse","Rain","Constellations","Perlin Flow","Petals","Sparkles","Embers","Leaves"]
    /// Reject unsupported schema, incomplete palettes and nonfinite effect inputs.
    func validate() throws {
        guard version == 1, !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              Self.roles.allSatisfy({ Self.validHex(palette[$0] ?? "") }), Self.validHex(effect.color),
              ["Monospace","Sans Serif","Serif"].contains(typography.font),
              ["Small","Default","Large"].contains(typography.text_size),
              ["Compact","Comfortable","Roomy"].contains(typography.density),
              Self.effects.contains(effect.name), effect.speed.isFinite, (0.05...4).contains(effect.speed),
              effect.intensity.isFinite, (0.05...4).contains(effect.intensity),
              effect.quality.isFinite, (0.25...2).contains(effect.quality),
              effect.size.isFinite, (0.25...3).contains(effect.size) else { throw CompanionError("Invalid version-one theme bundle") }
    }
    static func validHex(_ value: String) -> Bool {
        value.range(of:"^#[0-9a-fA-F]{6}$",options:.regularExpression) != nil
    }
    /// Preserve exported desktop colors while lifting rendered text/button color
    /// contrast to WCAG AA against the active panel/background when necessary.
    func color(_ role: String) -> Color {
        let raw = palette[role] ?? "#ffffff"
        guard ["text","muted","accent"].contains(role) else { return Color(hex:raw) }
        return Color(hex:Self.accessibleHex(raw,against:palette["panel"] ?? "#000000"))
    }
    static func contrast(_ lhs: String,_ rhs: String) -> Double {
        func luminance(_ hex: String) -> Double {
            let n = UInt32(hex.dropFirst(),radix:16) ?? 0
            let channels = [Double((n >> 16)&255)/255,Double((n >> 8)&255)/255,Double(n&255)/255]
            let linear = channels.map { $0 <= 0.04045 ? $0/12.92 : pow(($0+0.055)/1.055,2.4) }
            return linear[0]*0.2126 + linear[1]*0.7152 + linear[2]*0.0722
        }
        let a = luminance(lhs), b = luminance(rhs)
        return (max(a,b)+0.05)/(min(a,b)+0.05)
    }
    static func accessibleHex(_ source: String,against background: String) -> String {
        if contrast(source,background) >= 4.5 { return source }
        let n = UInt32(source.dropFirst(),radix:16) ?? 0
        let channels = [Double((n >> 16)&255),Double((n >> 8)&255),Double(n&255)]
        let target = contrast("#ffffff",background) >= contrast("#000000",background) ? 255.0 : 0.0
        for step in 1...20 {
            let t = Double(step)/20
            let c = channels.map { Int(($0+(target-$0)*t).rounded()) }
            let candidate = String(format:"#%02x%02x%02x",c[0],c[1],c[2])
            if contrast(candidate,background) >= 4.5 { return candidate }
        }
        return target == 255 ? "#ffffff" : "#000000"
    }
    var isLight: Bool {
        let value = UInt32((palette["background"] ?? "#000000").dropFirst(),radix:16) ?? 0
        let red: Double = Double((value >> 16) & 255)
        let green: Double = Double((value >> 8) & 255)
        let blue: Double = Double(value & 255)
        let brightness: Double = red * 0.2126 + green * 0.7152 + blue * 0.0722
        return brightness > 128
    }
    var fontDesign: Font.Design { typography.font == "Monospace" ? .monospaced : typography.font == "Serif" ? .serif : .default }
    var spacing: CGFloat { typography.density == "Compact" ? 8 : typography.density == "Roomy" ? 20 : 14 }
    static let presets: [String:ThemeBundle] = [
        "original": ThemeBundle(name:"Original",palette:["background":"#0f2030","panel":"#0d1b28","sidebar":"#0b1823","border":"#225b7b","text":"#55b8f6","muted":"#326a88","accent":"#44acf3","input_bg":"#0d1b28","send_bg":"#164866"]),
        "light": ThemeBundle(name:"Light",palette:["background":"#f4f1e8","panel":"#fffdf7","sidebar":"#ece8df","border":"#c7a789","text":"#4a3830","muted":"#8a7469","accent":"#c37d5c","input_bg":"#ffffff","send_bg":"#d9a585"]),
        "midnight": ThemeBundle(name:"Midnight",palette:["background":"#111321","panel":"#15192a","sidebar":"#0e1020","border":"#3a4165","text":"#dbe3ff","muted":"#7781a7","accent":"#ff5b69","input_bg":"#121626","send_bg":"#51333f"]),
        "paper": ThemeBundle(name:"Paper",palette:["background":"#f7f5ee","panel":"#ffffff","sidebar":"#ece9df","border":"#c9c4b4","text":"#20231f","muted":"#74786e","accent":"#a6a04f","input_bg":"#fbfaf5","send_bg":"#dad6a7"]),
        "cyberpunk": ThemeBundle(name:"Cyberpunk",palette:["background":"#0d1521","panel":"#101b28","sidebar":"#0a111b","border":"#205067","text":"#dff9ff","muted":"#52bac8","accent":"#f134d0","input_bg":"#0a1821","send_bg":"#2a5263"]),
        "retrowave": ThemeBundle(name:"Retrowave",palette:["background":"#18101f","panel":"#21142a","sidebar":"#130d19","border":"#5a315f","text":"#f4b0d8","muted":"#936080","accent":"#e45276","input_bg":"#1b1022","send_bg":"#5b2c4a"]),
        "forest": ThemeBundle(name:"Forest",palette:["background":"#1d2521","panel":"#19201c","sidebar":"#151c18","border":"#345241","text":"#77d89c","muted":"#567262","accent":"#67cf92","input_bg":"#171f1b","send_bg":"#315d43"]),
        "ocean": ThemeBundle(name:"Ocean",palette:["background":"#0e2230","panel":"#0d1d29","sidebar":"#0b1721","border":"#1c617a","text":"#5ec8f7","muted":"#3a748d","accent":"#58bbef","input_bg":"#0b1b25","send_bg":"#1c5670"]),
        "ume": ThemeBundle(name:"Ume",palette:["background":"#2a2030","panel":"#251b2b","sidebar":"#211824","border":"#694d67","text":"#f0add1","muted":"#a47190","accent":"#f49bc9","input_bg":"#241a28","send_bg":"#69405d"]),
        "copper": ThemeBundle(name:"Copper",palette:["background":"#1d1612","panel":"#19120f","sidebar":"#17110f","border":"#6c4425","text":"#efbd8a","muted":"#8c6b50","accent":"#e27d4e","input_bg":"#17110f","send_bg":"#6c4129"]),
        "terminal": ThemeBundle(name:"Terminal",palette:["background":"#07110d","panel":"#09140f","sidebar":"#06100b","border":"#1c5b3a","text":"#4cff86","muted":"#269e52","accent":"#18e665","input_bg":"#06110c","send_bg":"#155c31"]),
        "organs": ThemeBundle(name:"Organs",palette:["background":"#211718","panel":"#1d1415","sidebar":"#1a1213","border":"#67343a","text":"#e8a7aa","muted":"#925f64","accent":"#d44c57","input_bg":"#1c1314","send_bg":"#663139"]),
        "lavender": ThemeBundle(name:"Lavender",palette:["background":"#181722","panel":"#1d1b28","sidebar":"#15141e","border":"#50456d","text":"#d6c7f8","muted":"#8676ab","accent":"#8a65cb","input_bg":"#181622","send_bg":"#554070"]),
        "gpt": ThemeBundle(name:"GPT",palette:["background":"#1f2422","panel":"#1b201e","sidebar":"#171b19","border":"#53615b","text":"#dce7e2","muted":"#85908b","accent":"#9da8a3","input_bg":"#191d1b","send_bg":"#4e5a55"]),
        "claude": ThemeBundle(name:"Claude",palette:["background":"#25201c","panel":"#211c18","sidebar":"#1d1916","border":"#624d41","text":"#f1c6aa","muted":"#9c7b69","accent":"#e58255","input_bg":"#1f1a17","send_bg":"#6e4633"]),
        "cute": ThemeBundle(name:"Cute",palette:["background":"#251d26","panel":"#211820","sidebar":"#1e161d","border":"#704359","text":"#ffdbe8","muted":"#a17086","accent":"#ef739d","input_bg":"#211820","send_bg":"#753d56"])
    ]
}

extension Color {
    /// Convert previously validated six-digit semantic colors into sRGB.
    init(hex: String) {
        let value = UInt32(hex.dropFirst(),radix:16) ?? 0xffffff
        self.init(.sRGB,red:Double((value >> 16) & 255)/255,green:Double((value >> 8) & 255)/255,blue:Double(value & 255)/255,opacity:1)
    }
}

extension ThemeTypography {
    private enum Keys: String,CodingKey { case font,text_size,density,frosted }
    /// Match desktop defaults for omitted fields, rejecting malformed present values.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy:Keys.self)
        if c.contains(.font) { font = try c.decode(String.self,forKey:.font) }
        if c.contains(.text_size) { text_size = try c.decode(String.self,forKey:.text_size) }
        if c.contains(.density) { density = try c.decode(String.self,forKey:.density) }
        if c.contains(.frosted) { frosted = try c.decode(Bool.self,forKey:.frosted) }
    }
}
extension ThemeEffect {
    private enum Keys: String,CodingKey { case name,color,speed,intensity,quality,size,paused }
    init(from decoder: Decoder) throws {
        self.init(name:"Solid")
        let c = try decoder.container(keyedBy:Keys.self)
        if c.contains(.name) { name = try c.decode(String.self,forKey:.name) }
        if c.contains(.color) { color = try c.decode(String.self,forKey:.color) }
        if c.contains(.speed) { speed = try c.decode(Double.self,forKey:.speed) }
        if c.contains(.intensity) { intensity = try c.decode(Double.self,forKey:.intensity) }
        if c.contains(.quality) { quality = try c.decode(Double.self,forKey:.quality) }
        if c.contains(.size) { size = try c.decode(Double.self,forKey:.size) }
        if c.contains(.paused) { paused = try c.decode(Bool.self,forKey:.paused) }
    }
}
extension ThemeBundle {
    private enum Keys: String,CodingKey { case version,name,palette,typography,effect }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:Keys.self)
        self.init(name:try c.decode(String.self,forKey:.name),palette:try c.decode([String:String].self,forKey:.palette))
        version = try c.decode(Int.self,forKey:.version)
        if c.contains(.typography) { typography = try c.decode(ThemeTypography.self,forKey:.typography) }
        if c.contains(.effect) { effect = try c.decode(ThemeEffect.self,forKey:.effect) }
        else { effect = ThemeEffect(name:"Solid",color:palette["accent"] ?? "") }
        // A present partial effect also inherits the desktop palette accent.
        if c.contains(.effect) {
            let raw = try c.nestedContainer(keyedBy:ThemeEffectColorKey.self,forKey:.effect)
            if !raw.contains(.color) { effect.color = palette["accent"] ?? "" }
        }
        name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        palette = palette.mapValues { $0.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() }
        effect.color = effect.color.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        try validate()
    }
    private enum ThemeEffectColorKey: String,CodingKey { case color }
}
