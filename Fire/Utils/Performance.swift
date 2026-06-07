//
//  Performance.swift
//  Fire
//
//  Created by qwertyyb on 2026/6/6.
//

import Foundation
import OSLog
import QuartzCore
import StdoutExporter
import OpenTelemetryApi
import OpenTelemetrySdk

class Performance {
//    static func measure<T>(_ name: StaticString, operation: () throws -> T) rethrows -> T {
//        let startTime = CACurrentMediaTime()
//        Logger.performance.notice("[Performance] measure start, name: \(name, privacy: .public), start: \(startTime, privacy: .public)")
//        
//        defer {
//            Logger.performance.notice("[Performance] measure end, name: \(name, privacy: .public), end: \(startTime, privacy: .public), duration: \((CACurrentMediaTime() - startTime) * 1000, privacy: .public)ms")
//        }
//        
//        return try operation()
//    }
    /// 自动捕获：类名 + 方法名
    static func measure<T>(
        file: String = #file,
        function: String = #function,
        _ attrs: [String: Any]? = nil,
        operation: () throws -> T
    ) rethrows -> T {
        let fileName = (file as NSString).lastPathComponent.components(separatedBy: ".").first ?? "UnknownFile"
        let methodName = function
        let name = "\(fileName).\(methodName)"
        let extraText = "{\(String(describing: attrs?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")))}"
        
        let start = CACurrentMediaTime()
        Logger.performance.notice("[Performance] \(name, privacy: .public), attrs: \(extraText, privacy: .public), start: \(start, privacy: .public)")
        
        defer {
            let end = CACurrentMediaTime()
            Logger.performance.notice("[Performance] \(name, privacy: .public), attrs: \(extraText, privacy: .public), end: \(end, privacy: .public), duration: \((end - start) * 1000, privacy: .public)ms")
        }
        
        return try operation()
    }
    
    private let tracer: TracerSdk
    
    init() {
        let spanExporter = StdoutSpanExporter(isDebug: true)
        let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)

        let instrumentationScopeName = Bundle.main.bundleIdentifier ?? "com.qwertyyb.inputmethod.Fire"
        let instrumentationScopeVersion = "1.0.0"

        OpenTelemetry.registerTracerProvider(tracerProvider:
            TracerProviderBuilder()
                .add(spanProcessor: spanProcessor)
                .build()
        )
        tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: instrumentationScopeName, instrumentationVersion: instrumentationScopeVersion) as! TracerSdk
    }
    
    func span<T>(
        file: String = #file,
        function: String = #function,
        _ attrs: [String: AttributeValue]? = nil,
        operation: () throws -> T
    ) rethrows -> T {
        let fileName = (file as NSString).lastPathComponent.components(separatedBy: ".").first ?? "UnknownFile"
        let methodName = function
        let name = "\(fileName).\(methodName)"
        let extraText = "{\(String(describing: attrs?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")))}"
        
        let span = tracer.spanBuilder(spanName: name).startSpan()
        if let attrs = attrs {
            span.setAttributes(attrs)
        }
        
        let start = CACurrentMediaTime()
        Logger.performance.notice("[Performance] \(name, privacy: .public), attrs: \(extraText, privacy: .public), start: \(start, privacy: .public)")
        
        defer {
            let end = CACurrentMediaTime()
            Logger.performance.notice("[Performance] \(name, privacy: .public), attrs: \(extraText, privacy: .public), end: \(end, privacy: .public), duration: \((end - start) * 1000, privacy: .public)ms")
            span.end()
        }
        
        return try operation()
    }
    
    static var shared = Performance()
}
