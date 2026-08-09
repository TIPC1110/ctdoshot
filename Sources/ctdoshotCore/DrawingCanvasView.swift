import SwiftUI
import AppKit

enum ToolType: String, CaseIterable, Identifiable {
    case select = "Select"
    case arrow = "Arrow"
    case text = "Text"
    case stepNumber = "Step Counter"
    case rectangle = "Rectangle"
    case blur = "Blur / Mosaic"
    case crop = "Crop"
    case pencil = "Freehand Pencil"

    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .select: return "arrow.north.west"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .stepNumber: return "number.circle"
        case .rectangle: return "square"
        case .blur: return "square.dashed.square"
        case .crop: return "crop"
        case .pencil: return "pencil.tip"
        }
    }
}

struct ShapeElement: Identifiable, Equatable {
    let id: UUID
    let type: ToolType
    var points: [CGPoint]
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: Color
    var text: String

    init(
        id: UUID = UUID(),
        type: ToolType,
        points: [CGPoint] = [],
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        color: Color = .red,
        text: String = ""
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.text = text
    }
}

struct DrawingCanvasView: View {
    @Binding var bgImage: NSImage
    @State private var currentTool: ToolType = .arrow
    @State private var selectedColor: Color = .red
    @State private var elements: [ShapeElement] = []
    @State private var undoStack: [[ShapeElement]] = []
    @State private var redoStack: [[ShapeElement]] = []
    @State private var currentStart: CGPoint?
    @State private var currentEnd: CGPoint?
    @State private var currentPencilPoints: [CGPoint] = []
    @State private var stepCounter: Int = 1
    @State private var fitSize: CGSize = .zero

    var onCopy: (NSImage) -> Void
    var onSave: (NSImage) -> Void
    var onPin: (NSImage) -> Void
    var onOCR: (NSImage) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            editorCanvas
        }
        .background(shortcutBoard)
        .focusable()
    }

    private var shortcutBoard: some View {
        ZStack {
            Button(action: { emitComposite(onCopy) }) { EmptyView() }
                .keyboardShortcut("c", modifiers: .control)
            Button(action: { emitComposite(onCopy) }) { EmptyView() }
                .keyboardShortcut("c", modifiers: .command)
            Button(action: { emitComposite(onSave) }) { EmptyView() }
                .keyboardShortcut("s", modifiers: .command)
            Button(action: undo) { EmptyView() }
                .keyboardShortcut("z", modifiers: .command)
            Button(action: redo) { EmptyView() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                toolbarIconButton(
                    systemName: "doc.on.doc",
                    help: "editor.copy_clipboard".localized + " (⌃C / ⌘C)",
                    enabled: true,
                    action: { emitComposite(onCopy) }
                )

                toolbarIconButton(
                    systemName: "square.and.arrow.down",
                    help: "editor.save_image".localized + " (⌘S)",
                    enabled: true,
                    action: { emitComposite(onSave) }
                )

                toolbarIconButton(
                    systemName: "pin",
                    help: "editor.pin_screen".localized,
                    enabled: true,
                    action: { emitComposite(onPin) }
                )

                toolbarIconButton(
                    systemName: "crop",
                    help: "editor.crop_area".localized,
                    enabled: true,
                    action: { currentTool = .crop }
                )

                toolbarDivider

                toolbarIconButton(
                    systemName: "arrow.uturn.backward",
                    help: "Undo (⌘Z)",
                    enabled: !undoStack.isEmpty,
                    action: undo
                )

                toolbarIconButton(
                    systemName: "arrow.uturn.forward",
                    help: "Redo (⌘⇧Z)",
                    enabled: !redoStack.isEmpty,
                    action: redo
                )

                toolbarDivider

                ForEach(ToolType.allCases) { tool in
                    toolButton(tool)
                }

                toolbarDivider

                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                Text(colorHexLabel(selectedColor))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 64, alignment: .leading)
                    .help("editor.tab_to_copy".localized)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    labeledActionButton(
                        title: "OCR",
                        systemName: "text.viewfinder",
                        prominent: false,
                        action: { emitComposite(onOCR) }
                    )
                    .help("editor.ocr_btn".localized)

                    labeledActionButton(
                        title: "editor.save_btn".localized,
                        systemName: "checkmark.circle.fill",
                        prominent: true,
                        action: { emitComposite(onSave) }
                    )

                    labeledActionButton(
                        title: "editor.cancel_btn".localized,
                        systemName: "xmark",
                        prominent: false,
                        action: handleEscCancel
                    )
                    .keyboardShortcut(.escape, modifiers: [])

                    Text("\(Int(bgImage.size.width))×\(Int(bgImage.size.height))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .help("editor.image_size".localized)
                        .padding(.leading, 4)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 44)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 22)
    }

    private func toolbarIconButton(
        systemName: String,
        help: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(enabled ? Color.primary : Color.primary.opacity(0.28))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .opacity(enabled ? 1 : 0.7)
    }

    private func toolButton(_ tool: ToolType) -> some View {
        let selected = currentTool == tool
        return Button(action: { currentTool = tool }) {
            Image(systemName: tool.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.accentColor : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
    }

    private func labeledActionButton(
        title: String,
        systemName: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: prominent ? .semibold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color.primary.opacity(0.08))
            )
            .foregroundColor(prominent ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var editorCanvas: some View {
        GeometryReader { geo in
            let fit = fittedImageRect(imageSize: bgImage.size, in: geo.size)
            ZStack {
                CheckeredBackgroundView()

                ZStack {
                    Image(nsImage: bgImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fit.width, height: fit.height)

                    Canvas { context, size in
                        for elem in elements {
                            let viewElem = elementToView(elem, fit: size)
                            drawElement(viewElem, in: &context)
                        }
                    }
                    .frame(width: fit.width, height: fit.height)
                    .drawingGroup()

                    Canvas { context, size in
                        if let start = currentStart, let end = currentEnd {
                            if currentTool == .text { return }
                            let liveText: String = currentTool == .stepNumber ? "\(stepCounter)" : ""
                            let temp = ShapeElement(
                                type: currentTool,
                                points: currentPencilPoints,
                                startPoint: start,
                                endPoint: end,
                                color: selectedColor,
                                text: liveText
                            )
                            let viewElem = elementToView(temp, fit: size)
                            drawElement(viewElem, in: &context)
                        }
                    }
                    .frame(width: fit.width, height: fit.height)
                    .contentShape(Rectangle())
                    .gesture(drawGesture)
                }
                .frame(width: fit.width, height: fit.height)
                .position(x: fit.midX, y: fit.midY)
            }
            .onAppear { fitSize = fit.size }
            .onChange(of: geo.size) { _ in fitSize = fit.size }
        }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { val in
                let startImg = viewToImage(val.startLocation)
                let locImg = viewToImage(val.location)
                if currentStart == nil {
                    currentStart = startImg
                    if currentTool == .pencil {
                        currentPencilPoints = [startImg]
                    }
                }
                currentEnd = locImg
                if currentTool == .pencil {
                    currentPencilPoints.append(locImg)
                }
            }
            .onEnded { val in
                guard let start = currentStart else {
                    resetLiveStroke()
                    return
                }
                if currentTool == .select {
                    resetLiveStroke()
                    return
                }

                let endImg = viewToImage(val.location)

                if currentTool == .crop {
                    applyCrop(from: start, to: endImg)
                    resetLiveStroke()
                    return
                }

                if currentTool == .blur {
                    applyPixelate(from: start, to: endImg)
                    resetLiveStroke()
                    return
                }

                if currentTool == .text {
                    let anchor = start
                    resetLiveStroke()
                    promptForText(at: anchor)
                    return
                }

                var newElem = ShapeElement(
                    type: currentTool,
                    points: currentPencilPoints,
                    startPoint: start,
                    endPoint: endImg,
                    color: selectedColor
                )
                if currentTool == .stepNumber {
                    newElem.text = "\(stepCounter)"
                    stepCounter += 1
                }
                commitAppend(newElem)
                resetLiveStroke()
            }
    }

    private func promptForText(at point: CGPoint) {
        let alert = NSAlert()
        alert.messageText = "editor.text_prompt".localized
        alert.informativeText = ""
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "editor.cancel_btn".localized)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = ""
        field.placeholderString = "Text"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "\u{1b}"

        DispatchQueue.main.async {
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let newElem = ShapeElement(
                type: .text,
                startPoint: point,
                endPoint: point,
                color: selectedColor,
                text: text
            )
            commitAppend(newElem)
        }
    }

    private func commitAppend(_ element: ShapeElement) {
        undoStack.append(elements)
        redoStack.removeAll()
        elements.append(element)
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = previous
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = next
    }

    private func resetLiveStroke() {
        currentStart = nil
        currentEnd = nil
        currentPencilPoints = []
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let img = bgImage.size
        guard img.width > 0, img.height > 0 else { return .zero }
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        return CGRect(
            x: minX / img.width,
            y: minY / img.height,
            width: (maxX - minX) / img.width,
            height: (maxY - minY) / img.height
        )
    }

    private func applyCrop(from start: CGPoint, to end: CGPoint) {
        let nr = normalizedRect(from: start, to: end)
        guard nr.width > 0.001, nr.height > 0.001 else { return }

        let imgSize = bgImage.size
        let cropOrigin = CGPoint(x: nr.minX * imgSize.width, y: nr.minY * imgSize.height)
        let cropSize = CGSize(width: nr.width * imgSize.width, height: nr.height * imgSize.height)
        let cropRect = CGRect(origin: cropOrigin, size: cropSize)
        guard cropSize.width > 1, cropSize.height > 1 else { return }

        let remapped = elements.compactMap { remapElement($0, intoCrop: cropRect) }

        undoStack.append(elements)
        redoStack.removeAll()

        guard let cropped = ImageEffects.crop(bgImage, toNormalized: nr) else { return }
        bgImage = cropped
        elements = remapped
        if undoStack.count > 1 {
            undoStack = [undoStack.last!]
        }
    }

    private func remapElement(_ elem: ShapeElement, intoCrop crop: CGRect) -> ShapeElement? {
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x - crop.minX, y: p.y - crop.minY)
        }
        let mappedPoints = elem.points.map(map)
        let mappedStart = map(elem.startPoint)
        let mappedEnd = map(elem.endPoint)

        let originals = elem.points.isEmpty
            ? [elem.startPoint, elem.endPoint]
            : elem.points + [elem.startPoint, elem.endPoint]
        let intersects = originals.contains { crop.insetBy(dx: -2, dy: -2).contains($0) }
            || crop.intersects(CGRect(
                x: min(elem.startPoint.x, elem.endPoint.x),
                y: min(elem.startPoint.y, elem.endPoint.y),
                width: abs(elem.endPoint.x - elem.startPoint.x),
                height: abs(elem.endPoint.y - elem.startPoint.y)
            ))
        guard intersects else { return nil }

        return ShapeElement(
            id: elem.id,
            type: elem.type,
            points: mappedPoints,
            startPoint: mappedStart,
            endPoint: mappedEnd,
            color: elem.color,
            text: elem.text
        )
    }

    private func applyPixelate(from start: CGPoint, to end: CGPoint) {
        let nr = normalizedRect(from: start, to: end)
        guard nr.width > 0.001, nr.height > 0.001 else { return }
        guard let out = ImageEffects.pixelate(bgImage, normalizedRect: nr, scale: 8) else { return }
        bgImage = out
    }

    private func handleEscCancel() {
        let defaults = UserDefaults.standard
        let shouldCopy = defaults.object(forKey: "actionOnEscCopy") as? Bool ?? true
        let shouldSave = defaults.bool(forKey: "actionOnEscSave")
        let img = renderComposite()
        if shouldSave {
            onSave(img)
        } else if shouldCopy {
            onCopy(img)
        }
        onCancel()
    }

    private func emitComposite(_ handler: (NSImage) -> Void) {
        handler(renderComposite())
    }

    func renderComposite() -> NSImage {
        let pixel = pixelSize(of: bgImage)
        let pointSize = bgImage.size.width > 0 && bgImage.size.height > 0
            ? bgImage.size
            : CGSize(width: CGFloat(pixel.width), height: CGFloat(pixel.height))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixel.width,
            pixelsHigh: pixel.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return bgImage
        }
        rep.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return bgImage
        }
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext

        cg.translateBy(x: 0, y: pointSize.height)
        cg.scaleBy(x: 1, y: -1)

        if let cgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            cg.draw(cgImage, in: CGRect(origin: .zero, size: pointSize))
        } else {
            bgImage.draw(
                in: CGRect(origin: .zero, size: pointSize),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
        }

        let fitW = fitSize.width > 1 ? fitSize.width : pointSize.width
        let strokeScale = pointSize.width / max(fitW, 1)

        for elem in elements {
            strokeElementCG(elem, in: cg, strokeScale: strokeScale)
        }

        let out = NSImage(size: pointSize)
        out.addRepresentation(rep)
        return out
    }

    private func viewToImage(_ p: CGPoint) -> CGPoint {
        let img = bgImage.size
        let fit = fitSize.width > 1 && fitSize.height > 1 ? fitSize : img
        guard fit.width > 0, fit.height > 0, img.width > 0, img.height > 0 else { return p }
        return CGPoint(
            x: p.x * img.width / fit.width,
            y: p.y * img.height / fit.height
        )
    }

    private func imageToView(_ p: CGPoint, fit: CGSize) -> CGPoint {
        let img = bgImage.size
        guard img.width > 0, img.height > 0, fit.width > 0, fit.height > 0 else { return p }
        return CGPoint(
            x: p.x * fit.width / img.width,
            y: p.y * fit.height / img.height
        )
    }

    private func elementToView(_ elem: ShapeElement, fit: CGSize) -> ShapeElement {
        ShapeElement(
            id: elem.id,
            type: elem.type,
            points: elem.points.map { imageToView($0, fit: fit) },
            startPoint: imageToView(elem.startPoint, fit: fit),
            endPoint: imageToView(elem.endPoint, fit: fit),
            color: elem.color,
            text: elem.text
        )
    }

    private func strokeElementCG(_ elem: ShapeElement, in cg: CGContext, strokeScale: CGFloat) {
        let nsColor = NSColor(elem.color)
        cg.setStrokeColor(nsColor.cgColor)
        cg.setFillColor(nsColor.cgColor)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        let s = max(strokeScale, 0.5)

        let rect = CGRect(
            x: min(elem.startPoint.x, elem.endPoint.x),
            y: min(elem.startPoint.y, elem.endPoint.y),
            width: abs(elem.endPoint.x - elem.startPoint.x),
            height: abs(elem.endPoint.y - elem.startPoint.y)
        )

        switch elem.type {
        case .rectangle:
            cg.setLineWidth(3 * s)
            cg.stroke(rect)

        case .arrow:
            cg.setLineWidth(4 * s)
            cg.beginPath()
            cg.move(to: elem.startPoint)
            cg.addLine(to: elem.endPoint)
            cg.strokePath()
            let angle = atan2(elem.endPoint.y - elem.startPoint.y, elem.endPoint.x - elem.startPoint.x)
            let head: CGFloat = 14 * s
            let a1 = angle + .pi * 0.8
            let a2 = angle - .pi * 0.8
            cg.beginPath()
            cg.move(to: elem.endPoint)
            cg.addLine(to: CGPoint(x: elem.endPoint.x + cos(a1) * head, y: elem.endPoint.y + sin(a1) * head))
            cg.move(to: elem.endPoint)
            cg.addLine(to: CGPoint(x: elem.endPoint.x + cos(a2) * head, y: elem.endPoint.y + sin(a2) * head))
            cg.strokePath()

        case .pencil:
            guard let first = elem.points.first, elem.points.count > 1 else { return }
            cg.setLineWidth(3 * s)
            cg.beginPath()
            cg.move(to: first)
            for pt in elem.points.dropFirst() {
                cg.addLine(to: pt)
            }
            cg.strokePath()

        case .stepNumber:
            let r: CGFloat = 14 * s
            let circle = CGRect(x: elem.startPoint.x - r, y: elem.startPoint.y - r, width: r * 2, height: r * 2)
            cg.fillEllipse(in: circle)
            drawCGText(
                elem.text.isEmpty ? "?" : elem.text,
                at: elem.startPoint,
                fontSize: 14 * s,
                bold: true,
                color: .white,
                centered: true
            )

        case .text:
            drawCGText(
                elem.text.isEmpty ? "Text" : elem.text,
                at: elem.startPoint,
                fontSize: 16 * s,
                bold: false,
                color: nsColor,
                centered: false
            )

        case .blur:
            break

        case .crop, .select:
            break
        }
    }

    private func drawCGText(
        _ string: String,
        at point: CGPoint,
        fontSize: CGFloat,
        bold: Bool,
        color: NSColor,
        centered: Bool
    ) {
        let font = bold
            ? NSFont.boldSystemFont(ofSize: fontSize)
            : NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let ns = NSAttributedString(string: string, attributes: attrs)
        let size = ns.size()
        let flippedY = point.y
        let origin: CGPoint
        if centered {
            origin = CGPoint(x: point.x - size.width / 2, y: flippedY + size.height / 2)
        } else {
            origin = CGPoint(x: point.x, y: flippedY + size.height)
        }
        NSGraphicsContext.current?.cgContext.saveGState()
        NSGraphicsContext.current?.cgContext.translateBy(x: 0, y: origin.y)
        NSGraphicsContext.current?.cgContext.scaleBy(x: 1, y: -1)
        ns.draw(at: CGPoint(x: origin.x, y: 0))
        NSGraphicsContext.current?.cgContext.restoreGState()
    }

    private func drawElement(_ elem: ShapeElement, in context: inout GraphicsContext) {
        let rect = CGRect(
            x: min(elem.startPoint.x, elem.endPoint.x),
            y: min(elem.startPoint.y, elem.endPoint.y),
            width: abs(elem.endPoint.x - elem.startPoint.x),
            height: abs(elem.endPoint.y - elem.startPoint.y)
        )

        switch elem.type {
        case .rectangle:
            var path = Path()
            path.addRect(rect)
            context.stroke(path, with: .color(elem.color), lineWidth: 3)

        case .arrow:
            var path = Path()
            path.move(to: elem.startPoint)
            path.addLine(to: elem.endPoint)
            let angle = atan2(elem.endPoint.y - elem.startPoint.y, elem.endPoint.x - elem.startPoint.x)
            let head: CGFloat = 14
            path.move(to: elem.endPoint)
            path.addLine(to: CGPoint(
                x: elem.endPoint.x + cos(angle + .pi * 0.8) * head,
                y: elem.endPoint.y + sin(angle + .pi * 0.8) * head
            ))
            path.move(to: elem.endPoint)
            path.addLine(to: CGPoint(
                x: elem.endPoint.x + cos(angle - .pi * 0.8) * head,
                y: elem.endPoint.y + sin(angle - .pi * 0.8) * head
            ))
            context.stroke(path, with: .color(elem.color), lineWidth: 4)

        case .pencil:
            guard elem.points.count > 1 else { return }
            var path = Path()
            path.move(to: elem.points[0])
            for pt in elem.points.dropFirst() {
                path.addLine(to: pt)
            }
            context.stroke(path, with: .color(elem.color), lineWidth: 3)

        case .stepNumber:
            let circleRect = CGRect(x: elem.startPoint.x - 14, y: elem.startPoint.y - 14, width: 28, height: 28)
            var path = Path()
            path.addEllipse(in: circleRect)
            context.fill(path, with: .color(elem.color))
            let text = Text(elem.text).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            context.draw(text, at: elem.startPoint, anchor: .center)

        case .text:
            let label = elem.text.isEmpty ? "Text" : elem.text
            let text = Text(label).font(.system(size: 16, weight: .medium)).foregroundColor(elem.color)
            context.draw(text, at: elem.startPoint, anchor: .topLeading)

        case .blur:
            var path = Path()
            path.addRect(rect)
            context.fill(path, with: .color(.black.opacity(0.25)))

        case .crop:
            var path = Path()
            path.addRect(rect)
            context.stroke(path, with: .color(.white), lineWidth: 1.5)
            context.stroke(
                path,
                with: .color(.accentColor),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )

        case .select:
            break
        }
    }

    private func fittedImageRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(
            x: (container.width - w) / 2,
            y: (container.height - h) / 2,
            width: w,
            height: h
        )
    }

    private func pixelSize(of image: NSImage) -> (width: Int, height: Int) {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return (cg.width, cg.height)
        }
        let w = max(1, Int(round(image.size.width)))
        let h = max(1, Int(round(image.size.height)))
        return (w, h)
    }

    private func colorHexLabel(_ color: Color) -> String {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.deviceRGB) else { return "#------" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct CheckeredBackgroundView: View {
    var body: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 16
            let cols = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))

            for r in 0..<rows {
                for c in 0..<cols {
                    if (r + c) % 2 == 0 {
                        let rect = CGRect(
                            x: CGFloat(c) * tileSize,
                            y: CGFloat(r) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        context.fill(Path(rect), with: .color(Color.gray.opacity(0.15)))
                    }
                }
            }
        }
    }
}
