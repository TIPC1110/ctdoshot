import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "System"
    case en = "English"
    case vi = "Tiếng Việt"

    var id: String { rawValue }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .system {
        didSet {
            objectWillChange.send()
        }
    }

    private var activeLanguageCode: String {
        switch currentLanguage {
        case .system:
            let sysLang: String
            if #available(macOS 13.0, *) {
                sysLang = Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                sysLang = Locale.current.languageCode ?? "en"
            }
            return sysLang == "vi" ? "vi" : "en"
        case .en:
            return "en"
        case .vi:
            return "vi"
        }
    }

    func string(_ key: String) -> String {
        let dict = activeLanguageCode == "vi" ? viDict : enDict
        return dict[key] ?? enDict[key] ?? key
    }
}

private let enDict: [String: String] = [
    // Menu Bar
    "menu.reopen": "Reopen ctdoshot",
    "menu.capture_screen": "Capture Screen",
    "menu.capture_area": "Capture Area",
    "menu.capture_window": "Capture Active Window",
    "menu.capture_last_region": "Capture Last Region",
    "menu.scrolling_capture": "Scrolling Capture",
    "menu.recognize_ocr": "Recognize Text / QR",
    "menu.launch_startup": "Launch at Startup",
    "menu.settings": "Settings...",
    "menu.quit": "Quit ctdoshot",
    "menu.history": "Capture History",
    "menu.history_search_placeholder": "Search by OCR text or filename…",

    // Editor Toolbar
    "editor.select": "Select",
    "editor.arrow": "Arrow",
    "editor.text": "Text",
    "editor.text_prompt": "Enter annotation text",
    "editor.step_counter": "Step Counter",
    "editor.rectangle": "Rectangle",
    "editor.blur": "Blur / Mosaic",
    "editor.pencil": "Freehand Pencil",
    "editor.copy_clipboard": "Copy to Clipboard",
    "editor.save_image": "Save Image",
    "editor.pin_screen": "Pin to Screen",
    "editor.crop_area": "Crop Area",
    "editor.tab_to_copy": "Tab to copy",
    "editor.image_size": "Image size",
    "editor.zoom": "Zoom",
    "editor.ocr_btn": "OCR (Text)",
    "editor.pin_btn": "Pin",
    "editor.save_btn": "Save & Copy",
    "editor.cancel_btn": "Cancel",

    // Preferences
    "pref.title": "Preferences",
    "pref.tab_general": "General",
    "pref.tab_hotkeys": "Hotkeys",
    "pref.tab_advanced": "Advanced",
    "pref.bg_title": "Window Screenshot Background",
    "pref.bg_wallpaper": "Wallpaper",
    "pref.bg_transparent": "Transparent",
    "pref.bg_solid": "Solid Color",
    "pref.bg_trim": "Trim shadow",
    "pref.folder": "Screenshots folder:",
    "pref.choose": "Choose...",
    "pref.save_format": "Save format:",
    "pref.downscale_retina": "Downscale retina screenshots to 1x when saving",
    "pref.scroll_max": "Scrolling screenshot max height:",
    "pref.autostart": "Launch at startup",
    "pref.after_shot": "After screenshot:",
    "pref.after_show": "Show",
    "pref.after_copy": "Copy",
    "pref.after_save": "Save",
    "pref.language": "Language / Ngôn ngữ:",
    "pref.hotkeys_hint": "Click a shortcut to record a new global hotkey. Esc cancels recording. Defaults: Area ⇧⌘S · Scroll ⌥⇧⌘X (not ⌥⇧⌘S, to avoid mis-hits).",
    "pref.open_sys_settings": "Open System Settings",
    "pref.ocr_lang": "Primary OCR language:",
    "pref.remove_line_breaks": "Remove line breaks in OCR text",
    "pref.action_on_esc": "Action when hiding with Esc:",

    // Hotkey recorder
    "hotkey.recording": "Press new shortcut…",
    "hotkey.conflict": "Conflicts with %@",
    "hotkey.row_help": "Click to rebind. Current:",

    // Capture / scroll
    "capture.scroll_partial": "Scrolling capture stopped early — showing partial result.",

    // Notifications & Alerts
    "notif.saved_copied": "Saved & copied to Clipboard!",
    "notif.saved": "Saved screenshot!",
    "notif.copied": "Copied to Clipboard!",
    "ocr.copied_alert": "Recognized text copied to clipboard!",
    "ocr.working": "Recognizing text…",
    "ocr.failed": "No text found. Try a clearer region or set OCR language in Preferences."
]

private let viDict: [String: String] = [
    // Menu Bar
    "menu.reopen": "Mở lại ctdoshot",
    "menu.capture_screen": "Chụp toàn màn hình",
    "menu.capture_area": "Chụp vùng chọn",
    "menu.capture_window": "Chụp cửa sổ đang mở",
    "menu.capture_last_region": "Chụp vùng gần nhất",
    "menu.scrolling_capture": "Chụp cuộn trang",
    "menu.recognize_ocr": "Nhận diện Văn bản / Mã QR",
    "menu.launch_startup": "Khởi động cùng macOS",
    "menu.settings": "Cài đặt...",
    "menu.quit": "Thoát ctdoshot",
    "menu.history": "Lịch sử ảnh chụp",
    "menu.history_search_placeholder": "Tìm theo chữ OCR hoặc tên file…",

    // Editor Toolbar
    "editor.select": "Chọn vùng",
    "editor.arrow": "Mũi tên",
    "editor.text": "Chèn chữ",
    "editor.text_prompt": "Nhập nội dung chú thích",
    "editor.step_counter": "Đánh số thứ tự",
    "editor.rectangle": "Hình chữ nhật",
    "editor.blur": "Làm mờ / Mosaic",
    "editor.pencil": "Bút vẽ tự do",
    "editor.copy_clipboard": "Copy vào Khay nhớ tạm",
    "editor.save_image": "Lưu hình ảnh",
    "editor.pin_screen": "Ghim nổi màn hình",
    "editor.crop_area": "Cắt khung",
    "editor.tab_to_copy": "Tab để copy",
    "editor.image_size": "Kích thước ảnh",
    "editor.zoom": "Tỷ lệ zoom",
    "editor.ocr_btn": "OCR (Đọc chữ)",
    "editor.pin_btn": "Ghim nổi",
    "editor.save_btn": "Lưu & Copy",
    "editor.cancel_btn": "Hủy bỏ",

    // Preferences
    "pref.title": "Cài đặt",
    "pref.tab_general": "Chung",
    "pref.tab_hotkeys": "Phím tắt",
    "pref.tab_advanced": "Nâng cao",
    "pref.bg_title": "Hình nền Cửa sổ Chụp",
    "pref.bg_wallpaper": "Hình nền",
    "pref.bg_transparent": "Trong suốt",
    "pref.bg_solid": "Màu đơn",
    "pref.bg_trim": "Cắt bóng",
    "pref.folder": "Thư mục lưu ảnh:",
    "pref.choose": "Chọn...",
    "pref.save_format": "Định dạng file:",
    "pref.downscale_retina": "Tự động giảm tỷ lệ ảnh Retina xuống 1x khi lưu",
    "pref.scroll_max": "Chiều cao tối đa chụp cuộn:",
    "pref.autostart": "Tự khởi động cùng hệ thống",
    "pref.after_shot": "Sau khi chụp ảnh:",
    "pref.after_show": "Hiển thị",
    "pref.after_copy": "Copy",
    "pref.after_save": "Lưu file",
    "pref.language": "Language / Ngôn ngữ:",
    "pref.hotkeys_hint": "Bấm phím tắt để ghi lại. Esc hủy. Mặc định: Vùng ⇧⌘S · Cuộn ⌥⇧⌘X (tránh nhầm ⌥⇧⌘S).",
    "pref.open_sys_settings": "Mở System Settings",
    "pref.ocr_lang": "Ngôn ngữ OCR chính:",
    "pref.remove_line_breaks": "Xóa ký tự xuống dòng khi đọc OCR",
    "pref.action_on_esc": "Hành động khi bấm Esc ẩn cửa sổ:",

    // Hotkey recorder
    "hotkey.recording": "Nhấn tổ hợp phím mới…",
    "hotkey.conflict": "Trùng với %@",
    "hotkey.row_help": "Bấm để đổi phím. Hiện tại:",

    // Capture / scroll
    "capture.scroll_partial": "Chụp cuộn dừng sớm — hiển thị kết quả một phần.",

    // Notifications & Alerts
    "notif.saved_copied": "Đã lưu & copy vào Clipboard!",
    "notif.saved": "Đã lưu ảnh chụp!",
    "notif.copied": "Đã copy vào Clipboard!",
    "ocr.copied_alert": "Đã đọc chữ và copy vào Clipboard!",
    "ocr.working": "Đang nhận diện chữ…",
    "ocr.failed": "Không thấy chữ. Thử vùng rõ hơn hoặc đặt ngôn ngữ OCR trong Cài đặt."
]

extension String {
    var localized: String {
        return LanguageManager.shared.string(self)
    }
}
