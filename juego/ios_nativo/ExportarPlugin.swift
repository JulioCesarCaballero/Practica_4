import Flutter
import UIKit

/// Implementación iOS del canal "mx.ipn.escom/archivos" del juego.
/// En Android lo atiende MainActivity.kt con ACTION_CREATE_DOCUMENT; en iOS se usa el
/// selector de destino del sistema (UIDocumentPickerViewController en modo exportación,
/// que muestra la app Archivos: "En mi iPhone", iCloud Drive, etc.).
///
/// Método:  exportar(ruta, nombre, mime) -> String? (URL del archivo creado, o null si el usuario canceló)
final class ExportarPlugin: NSObject, UIDocumentPickerDelegate {
    static let nombreCanal = "mx.ipn.escom/archivos"
    private static var instancia: ExportarPlugin? // se retiene para que el canal siga vivo

    private let canal: FlutterMethodChannel
    private var resultadoPendiente: FlutterResult?
    private var temporal: URL?

    static func registrar(messenger: FlutterBinaryMessenger) {
        instancia = ExportarPlugin(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        canal = FlutterMethodChannel(name: ExportarPlugin.nombreCanal, binaryMessenger: messenger)
        super.init()
        canal.setMethodCallHandler { [weak self] call, result in
            guard call.method == "exportar" else { return result(FlutterMethodNotImplemented) }
            self?.exportar(call.arguments as? [String: Any] ?? [:], result)
        }
    }

    private func exportar(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard resultadoPendiente == nil else {
            return result(FlutterError(code: "OCUPADO", message: "Ya hay un selector abierto", details: nil))
        }
        guard let ruta = args["ruta"] as? String, let nombre = args["nombre"] as? String else {
            return result(FlutterError(code: "ERROR", message: "Argumentos no válidos", details: nil))
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: ruta) else {
            return result(FlutterError(code: "NO_ENCONTRADO", message: "No hay archivo para exportar", details: nil))
        }
        // Se exporta una copia con el nombre de la partida (el archivo original no se toca).
        let seguro = nombre.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "_")
        let dir = fm.temporaryDirectory.appendingPathComponent("exportar", isDirectory: true)
        let copia = dir.appendingPathComponent(seguro.isEmpty ? "partida" : seguro)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: copia.path) { try fm.removeItem(at: copia) }
            try fm.copyItem(at: URL(fileURLWithPath: ruta), to: copia)
        } catch let e as NSError {
            let sinEspacio = e.domain == NSCocoaErrorDomain && e.code == NSFileWriteOutOfSpaceError
            return result(FlutterError(code: sinEspacio ? "SIN_ESPACIO" : "ERROR", message: e.localizedDescription, details: nil))
        }
        guard let vc = Self.controladorSuperior() else {
            return result(FlutterError(code: "ERROR", message: "No hay pantalla para mostrar el selector", details: nil))
        }
        temporal = copia
        resultadoPendiente = result
        let picker = UIDocumentPickerViewController(forExporting: [copia], asCopy: true)
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        terminar(urls.first?.absoluteString)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        terminar(nil) // el usuario canceló: se respeta su decisión
    }

    private func terminar(_ valor: String?) {
        if let t = temporal { try? FileManager.default.removeItem(at: t) }
        temporal = nil
        let r = resultadoPendiente
        resultadoPendiente = nil
        r?(valor)
    }

    private static func controladorSuperior() -> UIViewController? {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ventana = escenas.flatMap { $0.windows }.first { $0.isKeyWindow } ?? escenas.first?.windows.first
        var vc = ventana?.rootViewController
        while let presentado = vc?.presentedViewController { vc = presentado }
        return vc
    }
}
