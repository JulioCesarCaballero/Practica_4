import Flutter
import UIKit
import UniformTypeIdentifiers

/// Implementación iOS del canal "mx.ipn.escom/saf" (el equivalente en Android es
/// MainActivity.kt, que usa el Storage Access Framework).
///
/// En iOS no existen las URI de SAF. El equivalente es:
///   - UIDocumentPickerViewController: selector del sistema (app Archivos).
///   - URL con alcance de seguridad (security-scoped URL) + bookmarks: permiso
///     persistente a la carpeta o archivo que el usuario eligió.
///   - FileManager dentro de startAccessingSecurityScopedResource().
///
/// Convenciones para hablar con Dart (mismas que en Android):
///   - "uri"  = URL de archivo (absoluteString) del documento.
///   - "raiz" = URL de la carpeta autorizada a la que pertenece.
/// Los ids que se devuelven a Dart se expresan siempre con la URL con la que se
/// guardó el bookmark ("clave"), para que los recientes y favoritos sigan siendo
/// válidos aunque el sistema cambie la ruta real tras reiniciar la app.
final class SafPlugin: NSObject {
    static let nombreCanal = "mx.ipn.escom/saf"
    private static let claveBookmarks = "saf_bookmarks_v1"

    private let canal: FlutterMethodChannel
    private let hilo = DispatchQueue(label: "mx.ipn.escom.saf", qos: .userInitiated)
    private var selector: SelectorDelegate?
    private var visorDocumentos: UIDocumentInteractionController?
    private var visorDelegate: VisorDelegate?

    /// Registra el canal. Llamar una vez que el motor de Flutter ya existe (ver AppDelegate.swift).
    private static var instancia: SafPlugin? // se retiene para que el manejador del canal siga vivo

    static func registrar(messenger: FlutterBinaryMessenger) {
        instancia = SafPlugin(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        canal = FlutterMethodChannel(name: SafPlugin.nombreCanal, binaryMessenger: messenger)
        super.init()
        canal.setMethodCallHandler { [weak self] call, result in self?.manejar(call, result) }
    }

    // MARK: - Despacho

    private func manejar(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        func texto(_ k: String) -> String? { args[k] as? String }

        switch call.method {
        case "elegirCarpeta":
            elegir(tipos: [.folder], carpeta: true, result: result)
        case "elegirArchivo":
            elegir(tipos: [.item], carpeta: false, result: result)
        case "exportar":
            guard let ruta = texto("ruta"), let nombre = texto("nombre") else { return result(Self.malo()) }
            exportar(ruta: ruta, nombre: nombre, result: result)
        case "carpetasAutorizadas":
            enSegundoPlano(result) { self.carpetasAutorizadas() }
        case "quitarAcceso":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            enSegundoPlano(result) { self.quitarAcceso(uri); return true }
        case "info":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.conAcceso(raiz: texto("raiz"), uri: uri) { (u: URL, c: Ctx) in try self.info(u, raiz: texto("raiz"), ctx: c) } }
        case "listar":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.conAcceso(raiz: texto("raiz"), uri: uri) { (u: URL, c: Ctx) in try self.listar(u, raiz: texto("raiz"), ctx: c) } }
        case "copiarACache":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            enSegundoPlano(result) {
                try self.conAcceso(raiz: nil, uri: uri) { (u: URL, _: Ctx) in try self.copiarACache(u, nombre: texto("nombre") ?? u.lastPathComponent) }
            }
        case "renombrar":
            guard let uri = texto("uri"), let nombre = texto("nombre") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.conAcceso(raiz: texto("raiz"), uri: uri) { (u: URL, c: Ctx) in try self.renombrar(u, nombre: nombre, raiz: texto("raiz"), ctx: c) } }
        case "eliminar":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            enSegundoPlano(result) {
                try self.conAcceso(raiz: self.raizDe(uri), uri: uri) { (u: URL, _: Ctx) -> Bool in try FileManager.default.removeItem(at: u); return true }
            }
        case "copiar":
            guard let uri = texto("uri"), let destino = texto("destino") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.copiarOMover(uri: uri, destino: destino, raiz: texto("raiz"), mover: false) }
        case "mover":
            guard let uri = texto("uri"), let destino = texto("destino") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.copiarOMover(uri: uri, destino: destino, raiz: texto("raiz"), mover: true) }
        case "crearCarpeta":
            guard let uri = texto("uri"), let nombre = texto("nombre") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.crear(en: uri, raiz: texto("raiz"), nombre: nombre, contenido: nil) }
        case "crearArchivo":
            guard let uri = texto("uri"), let nombre = texto("nombre") else { return result(Self.malo()) }
            enSegundoPlano(result) { try self.crear(en: uri, raiz: texto("raiz"), nombre: nombre, contenido: texto("texto") ?? "") }
        case "abrirCon":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            abrirCon(uri: uri, result: result)
        case "compartir":
            guard let uri = texto("uri") else { return result(Self.malo()) }
            compartir(uri: uri, result: result)
        case "espacioLibre":
            guard let ruta = texto("ruta") else { return result(Self.malo()) }
            enSegundoPlano(result) { self.espacioLibre(ruta) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Selector del sistema (UIDocumentPickerViewController)

    private func elegir(tipos: [UTType], carpeta: Bool, result: @escaping FlutterResult) {
        guard selector == nil else {
            return result(FlutterError(code: "OCUPADO", message: "Ya hay un selector abierto", details: nil))
        }
        // asCopy: false => se abre el documento "en el lugar" y se obtiene acceso con alcance de seguridad.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: tipos, asCopy: false)
        picker.allowsMultipleSelection = false
        let delegado = SelectorDelegate { [weak self] urls in
            guard let self = self else { return }
            self.selector = nil
            guard let url = urls?.first else { return result(nil) } // El usuario canceló: se respeta su decisión.
            self.hilo.async {
                do {
                    let datos = try self.autorizar(url)
                    DispatchQueue.main.async { result(datos) }
                } catch {
                    DispatchQueue.main.async { result(Self.error(error)) }
                }
            }
        }
        selector = delegado
        picker.delegate = delegado
        guard let vc = Self.controladorSuperior() else {
            selector = nil
            return result(FlutterError(code: "ERROR", message: "No hay pantalla para mostrar el selector", details: nil))
        }
        vc.present(picker, animated: true)
    }

    /// Guarda el bookmark (permiso persistente) y devuelve la información del elemento elegido.
    private func autorizar(_ url: URL) throws -> [String: Any] {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [NSLocalizedDescriptionKey: "El sistema no concedió acceso a la ubicación elegida"])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let datos = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        var todos = leerBookmarks()
        let clave = Self.clave(url)
        todos[clave] = datos
        guardarBookmarks(todos)
        let esCarpeta = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return try info(url, raiz: esCarpeta ? clave : nil, ctx: Ctx(clave: clave, base: url))
    }

    // MARK: - Exportar (UIDocumentPickerViewController en modo exportación)

    private func exportar(ruta: String, nombre: String, result: @escaping FlutterResult) {
        guard selector == nil else {
            return result(FlutterError(code: "OCUPADO", message: "Ya hay un selector abierto", details: nil))
        }
        let origen = URL(fileURLWithPath: ruta)
        guard FileManager.default.fileExists(atPath: ruta) else {
            return result(FlutterError(code: "NO_ENCONTRADO", message: "No hay archivo para exportar", details: nil))
        }
        // Se prepara una copia con el nombre pedido para que el destino lo conserve.
        let temporal = FileManager.default.temporaryDirectory.appendingPathComponent("exportar", isDirectory: true)
        let copia = temporal.appendingPathComponent(Self.nombreSeguro(nombre))
        do {
            try FileManager.default.createDirectory(at: temporal, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: copia.path) { try FileManager.default.removeItem(at: copia) }
            try FileManager.default.copyItem(at: origen, to: copia)
        } catch {
            return result(Self.error(error))
        }
        let picker = UIDocumentPickerViewController(forExporting: [copia], asCopy: true)
        let delegado = SelectorDelegate { [weak self] urls in
            self?.selector = nil
            try? FileManager.default.removeItem(at: copia)
            result(urls?.first?.absoluteString) // null = canceló
        }
        selector = delegado
        picker.delegate = delegado
        guard let vc = Self.controladorSuperior() else {
            selector = nil
            return result(FlutterError(code: "ERROR", message: "No hay pantalla para mostrar el selector", details: nil))
        }
        vc.present(picker, animated: true)
    }

    // MARK: - Bookmarks y acceso con alcance de seguridad

    private func leerBookmarks() -> [String: Data] {
        (UserDefaults.standard.dictionary(forKey: Self.claveBookmarks) as? [String: Data]) ?? [:]
    }

    private func guardarBookmarks(_ d: [String: Data]) {
        UserDefaults.standard.set(d, forKey: Self.claveBookmarks)
    }

    /// Clave estable de una URL (ruta normalizada, carpetas sin "/" final).
    private static func clave(_ url: URL) -> String {
        url.standardizedFileURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Devuelve la clave del bookmark que contiene a `uri` (la más específica).
    private func raizDe(_ uri: String) -> String? {
        let candidatas = leerBookmarks().keys.filter { Self.contiene($0, uri) }
        return candidatas.max { $0.count < $1.count }
    }

    private static func contiene(_ raiz: String, _ uri: String) -> Bool {
        let r = raiz.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let u = uri.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return u == r || u.hasPrefix(r + "/")
    }

    /// Resuelve el bookmark de la raíz, abre el acceso, ejecuta `bloque` con la URL real del
    /// documento y siempre cierra el acceso. Convierte la ruta "clave" en la ruta real actual.
    private func conAcceso<T>(raiz: String?, uri: String, _ bloque: (URL, Ctx) throws -> T) throws -> T {
        let todos = leerBookmarks()
        guard let clave = raiz.flatMap({ r in todos.keys.first { Self.contiene($0, r) } }) ?? raizDe(uri),
              let datos = todos[clave] else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError,
                          userInfo: [NSLocalizedDescriptionKey: "No hay permiso para esta ubicación. Vuelve a autorizarla."])
        }
        var obsoleto = false
        let base: URL
        do {
            base = try URL(resolvingBookmarkData: datos, options: [], relativeTo: nil, bookmarkDataIsStale: &obsoleto)
        } catch {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError,
                          userInfo: [NSLocalizedDescriptionKey: "El permiso a esta ubicación ya no es válido. Vuelve a autorizarla."])
        }
        guard base.startAccessingSecurityScopedResource() else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError,
                          userInfo: [NSLocalizedDescriptionKey: "Permiso denegado o revocado"])
        }
        defer { base.stopAccessingSecurityScopedResource() }
        if obsoleto, let nuevo = try? base.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            var t = todos; t[clave] = nuevo; guardarBookmarks(t)
        }
        return try bloque(Self.aReal(uri, clave: clave, base: base), Ctx(clave: clave, base: base))
    }

    /// Traduce una URL en "espacio clave" a la URL real actual (misma ruta relativa sobre la base resuelta).
    private static func aReal(_ uri: String, clave: String, base: URL) -> URL {
        let relativa = String(uri.trimmingCharacters(in: CharacterSet(charactersIn: "/")).dropFirst(clave.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .removingPercentEncoding ?? ""
        return relativa.isEmpty ? base : base.appendingPathComponent(relativa)
    }

    /// Traduce una URL real a "espacio clave" para devolverla a Dart.
    private static func aClave(_ real: URL, clave: String, base: URL) -> String {
        let rb = base.standardizedFileURL.path
        let rr = real.standardizedFileURL.path
        guard rr.hasPrefix(rb) else { return real.absoluteString }
        let relativa = String(rr.dropFirst(rb.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if relativa.isEmpty { return clave }
        let escapada = relativa.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relativa
        return clave + "/" + escapada
    }

    // MARK: - Consultas

    private func carpetasAutorizadas() -> [[String: Any]] {
        var lista: [[String: Any]] = []
        for (clave, datos) in leerBookmarks() {
            var obsoleto = false
            guard let url = try? URL(resolvingBookmarkData: datos, options: [], relativeTo: nil, bookmarkDataIsStale: &obsoleto) else {
                lista.append(Self.carpetaNoDisponible(clave))
                continue
            }
            guard url.startAccessingSecurityScopedResource() else {
                lista.append(Self.carpetaNoDisponible(clave))
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let esCarpeta = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard esCarpeta else { continue } // los archivos sueltos no se listan como carpetas
            if var d = try? info(url, raiz: clave, ctx: Ctx(clave: clave, base: url)) {
                d["disponible"] = true
                lista.append(d)
            } else {
                lista.append(Self.carpetaNoDisponible(clave))
            }
        }
        return lista.sorted { ($0["nombre"] as? String ?? "").localizedCaseInsensitiveCompare($1["nombre"] as? String ?? "") == .orderedAscending }
    }

    private static func carpetaNoDisponible(_ clave: String) -> [String: Any] {
        ["uri": clave, "raiz": clave,
         "nombre": URL(string: clave)?.lastPathComponent.removingPercentEncoding ?? "Carpeta",
         "esCarpeta": true, "disponible": false]
    }

    private func quitarAcceso(_ uri: String) {
        var t = leerBookmarks()
        for k in t.keys where Self.contiene(uri, k) { t.removeValue(forKey: k) }
        guardarBookmarks(t)
    }

    /// Información de un elemento. Los ids se devuelven en "espacio clave" (ver ctx).
    private func info(_ url: URL, raiz: String?, ctx: Ctx) throws -> [String: Any] {
        let llaves: Set<URLResourceKey> = [.nameKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
                                           .creationDateKey, .contentTypeKey]
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError,
                          userInfo: [NSLocalizedDescriptionKey: "El documento ya no existe o no está disponible"])
        }
        let v = try url.resourceValues(forKeys: llaves)
        let esCarpeta = v.isDirectory ?? false
        let escribible = fm.isWritableFile(atPath: url.path)
        let padreEscribible = fm.isWritableFile(atPath: url.deletingLastPathComponent().path)
        let tipo = v.contentType
        // Tipo MIME; si no existe se informa el UTType (la práctica pide "MIME/UTType").
        var mime: Any = NSNull()
        if !esCarpeta, let t = tipo?.preferredMIMEType ?? tipo?.identifier { mime = t }
        var tamano: Any = NSNull()
        if !esCarpeta, let t = v.fileSize { tamano = t }
        func ms(_ d: Date?) -> Any { d.map { Int($0.timeIntervalSince1970 * 1000) } ?? NSNull() }
        return [
            "uri": Self.aClave(url, clave: ctx.clave, base: ctx.base),
            "raiz": raiz ?? NSNull(),
            "nombre": v.name ?? url.lastPathComponent,
            "mime": mime,
            "esCarpeta": esCarpeta,
            "tamano": tamano,
            "modificado": ms(v.contentModificationDate),
            "creado": ms(v.creationDate),
            "puedeEscribir": escribible,
            "puedeEliminar": padreEscribible,
            "puedeRenombrar": padreEscribible,
            "puedeCrear": esCarpeta && escribible,
            "disponible": true,
        ]
    }

    private func listar(_ carpeta: URL, raiz: String?, ctx: Ctx) throws -> [[String: Any]] {
        let hijos = try FileManager.default.contentsOfDirectory(at: carpeta, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return hijos.compactMap { try? info($0, raiz: raiz, ctx: ctx) }
    }

    // MARK: - Operaciones

    private func copiarACache(_ url: URL, nombre: String) throws -> String {
        let dir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("saf", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Hash estable (hashValue de Swift cambia en cada ejecución).
        let hash = url.absoluteString.utf8.reduce(UInt32(5381)) { ($0 << 5) &+ $0 &+ UInt32($1) }
        let destino = dir.appendingPathComponent(String(hash, radix: 16) + "_" + Self.nombreSeguro(nombre))
        if FileManager.default.fileExists(atPath: destino.path) { try FileManager.default.removeItem(at: destino) }
        // Se usa NSFileCoordinator porque el documento puede estar en iCloud Drive u otro proveedor.
        var errorCoord: NSError?
        var errorCopia: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &errorCoord) { leible in
            do { try FileManager.default.copyItem(at: leible, to: destino) } catch { errorCopia = error }
        }
        if let e = errorCoord { throw e }
        if let e = errorCopia { throw e }
        return destino.path
    }

    private func renombrar(_ url: URL, nombre: String, raiz: String?, ctx: Ctx) throws -> [String: Any] {
        let destino = url.deletingLastPathComponent().appendingPathComponent(Self.nombreSeguro(nombre))
        if FileManager.default.fileExists(atPath: destino.path) {
            throw SafError.noSoportado("Ya existe un elemento con ese nombre")
        }
        try FileManager.default.moveItem(at: url, to: destino)
        return try info(destino, raiz: raiz, ctx: ctx)
    }

    private func copiarOMover(uri: String, destino: String, raiz: String?, mover: Bool) throws -> [String: Any] {
        // Origen y destino están en la misma carpeta autorizada (Dart lo valida). Se abre el acceso
        // con la raíz del destino, que contiene a ambos.
        try conAcceso(raiz: raiz ?? raizDe(destino), uri: uri) { (origenReal: URL, _: Ctx) -> [String: Any] in
            try conAcceso(raiz: raiz ?? raizDe(destino), uri: destino) { (carpetaReal: URL, ctx: Ctx) -> [String: Any] in
                var esCarpeta: ObjCBool = false
                guard FileManager.default.fileExists(atPath: carpetaReal.path, isDirectory: &esCarpeta), esCarpeta.boolValue else {
                    throw SafError.noSoportado("El destino debe ser una carpeta")
                }
                guard FileManager.default.isWritableFile(atPath: carpetaReal.path) else {
                    throw SafError.noSoportado("La carpeta destino no permite escribir")
                }
                var nuevo = carpetaReal.appendingPathComponent(origenReal.lastPathComponent)
                nuevo = Self.nombreLibre(nuevo)
                if mover { try FileManager.default.moveItem(at: origenReal, to: nuevo) }
                else { try FileManager.default.copyItem(at: origenReal, to: nuevo) }
                return try info(nuevo, raiz: raiz, ctx: ctx)
            }
        }
    }

    private func crear(en uri: String, raiz: String?, nombre: String, contenido: String?) throws -> [String: Any] {
        try conAcceso(raiz: raiz, uri: uri) { (carpeta: URL, ctx: Ctx) -> [String: Any] in
            guard FileManager.default.isWritableFile(atPath: carpeta.path) else {
                throw SafError.noSoportado("La carpeta no permite crear elementos")
            }
            let nuevo = carpeta.appendingPathComponent(Self.nombreSeguro(nombre))
            if FileManager.default.fileExists(atPath: nuevo.path) {
                throw SafError.noSoportado("Ya existe un elemento con ese nombre")
            }
            if let texto = contenido {
                try texto.write(to: nuevo, atomically: true, encoding: .utf8)
            } else {
                try FileManager.default.createDirectory(at: nuevo, withIntermediateDirectories: false)
            }
            return try info(nuevo, raiz: raiz, ctx: ctx)
        }
    }

    private func espacioLibre(_ ruta: String) -> Int? {
        let url = URL(fileURLWithPath: ruta)
        let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return v?.volumeAvailableCapacityForImportantUsage.map { Int($0) }
    }

    // MARK: - Abrir con / Compartir (menús del sistema)

    private func abrirCon(uri: String, result: @escaping FlutterResult) {
        hilo.async {
            do {
                let ruta: String = try self.conAcceso(raiz: self.raizDe(uri), uri: uri) { (u: URL, _: Ctx) -> String in try self.copiarACache(u, nombre: u.lastPathComponent) }
                DispatchQueue.main.async {
                    guard let vc = Self.controladorSuperior() else { return result(Self.sinApp()) }
                    let doc = UIDocumentInteractionController(url: URL(fileURLWithPath: ruta))
                    let delegado = VisorDelegate()
                    doc.delegate = delegado
                    self.visorDocumentos = doc
                    self.visorDelegate = delegado
                    let ancla = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 1, height: 1)
                    // presentOpenInMenu devuelve false si no hay ninguna app que pueda abrir el archivo.
                    if doc.presentOpenInMenu(from: ancla, in: vc.view, animated: true) { result(true) } else { result(Self.sinApp()) }
                }
            } catch {
                DispatchQueue.main.async { result(Self.error(error)) }
            }
        }
    }

    private func compartir(uri: String, result: @escaping FlutterResult) {
        hilo.async {
            do {
                let ruta: String = try self.conAcceso(raiz: self.raizDe(uri), uri: uri) { (u: URL, _: Ctx) -> String in try self.copiarACache(u, nombre: u.lastPathComponent) }
                DispatchQueue.main.async {
                    guard let vc = Self.controladorSuperior() else { return result(Self.sinApp()) }
                    let hoja = UIActivityViewController(activityItems: [URL(fileURLWithPath: ruta)], applicationActivities: nil)
                    // En iPad la hoja de compartir debe anclarse a una vista (popover).
                    hoja.popoverPresentationController?.sourceView = vc.view
                    hoja.popoverPresentationController?.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 1, height: 1)
                    vc.present(hoja, animated: true)
                    result(true)
                }
            } catch {
                DispatchQueue.main.async { result(Self.error(error)) }
            }
        }
    }

    // MARK: - Utilidades

    private func enSegundoPlano(_ result: @escaping FlutterResult, _ tarea: @escaping () throws -> Any?) {
        hilo.async {
            do {
                let valor = try tarea()
                DispatchQueue.main.async { result(valor) }
            } catch {
                DispatchQueue.main.async { result(Self.error(error)) }
            }
        }
    }

    private static func malo() -> FlutterError {
        FlutterError(code: "ERROR", message: "Argumentos no válidos", details: nil)
    }

    private static func sinApp() -> FlutterError {
        FlutterError(code: "SIN_APP", message: "No hay ninguna app para abrir este tipo de archivo", details: nil)
    }

    /// Traduce errores de Swift/Cocoa a los mismos códigos que usa el lado Android (ver errores.dart).
    private static func error(_ e: Error) -> FlutterError {
        if let s = e as? SafError { return FlutterError(code: "NO_SOPORTADO", message: s.mensaje, details: nil) }
        let ns = e as NSError
        let mensaje = ns.localizedDescription
        guard ns.domain == NSCocoaErrorDomain else { return FlutterError(code: "ERROR", message: mensaje, details: nil) }
        switch ns.code {
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError, NSFileReadInvalidFileNameError:
            return FlutterError(code: "NO_ENCONTRADO", message: mensaje, details: nil)
        case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
            return FlutterError(code: "PERMISO", message: mensaje, details: nil)
        case NSFileWriteOutOfSpaceError:
            return FlutterError(code: "SIN_ESPACIO", message: mensaje, details: nil)
        case NSFileWriteFileExistsError:
            return FlutterError(code: "NO_SOPORTADO", message: "Ya existe un elemento con ese nombre", details: nil)
        default:
            return FlutterError(code: "ERROR", message: mensaje, details: nil)
        }
    }

    private static func nombreSeguro(_ n: String) -> String {
        let prohibidos = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let limpio = n.components(separatedBy: prohibidos).joined(separator: "_").trimmingCharacters(in: .whitespaces)
        return limpio.isEmpty ? "archivo" : limpio
    }

    /// Si ya existe un archivo con ese nombre añade " (n)" antes de la extensión.
    private static func nombreLibre(_ url: URL) -> URL {
        var candidato = url
        var i = 1
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        while FileManager.default.fileExists(atPath: candidato.path) {
            let nombre = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            candidato = url.deletingLastPathComponent().appendingPathComponent(nombre)
            i += 1
        }
        return candidato
    }

    static func controladorSuperior() -> UIViewController? {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ventana = escenas.flatMap { $0.windows }.first { $0.isKeyWindow } ?? escenas.first?.windows.first
        var vc = ventana?.rootViewController
        while let presentado = vc?.presentedViewController { vc = presentado }
        return vc
    }
}

/// Raíz autorizada vigente: clave del bookmark y URL real resuelta en esta sesión.
private struct Ctx {
    let clave: String
    let base: URL
}

private enum SafError: Error {
    case noSoportado(String)
    var mensaje: String { if case .noSoportado(let m) = self { return m }; return "" }
}

/// Recibe el resultado del selector del sistema. `urls == nil` significa que el usuario canceló.
private final class SelectorDelegate: NSObject, UIDocumentPickerDelegate {
    private let alTerminar: ([URL]?) -> Void
    init(alTerminar: @escaping ([URL]?) -> Void) { self.alTerminar = alTerminar }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { alTerminar(urls) }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { alTerminar(nil) }
}

private final class VisorDelegate: NSObject, UIDocumentInteractionControllerDelegate {}
