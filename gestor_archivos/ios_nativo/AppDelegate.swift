import Flutter
import UIKit

// Reemplaza el AppDelegate.swift que genera "flutter create --platforms=ios .".
// Registra el canal propio de la práctica (SafPlugin.swift).
//
// VARIANTE A (plantilla con motor implícito, Flutter >= 3.38; es la que trae este archivo).
// VARIANTE B (plantilla clásica): ver el comentario al final.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SafPlugin.registrar(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/* VARIANTE B – plantilla clásica (si tu AppDelegate original NO tiene FlutterImplicitEngineDelegate):

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controlador = window?.rootViewController as! FlutterViewController
    SafPlugin.registrar(messenger: controlador.binaryMessenger)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
*/
