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
    private let tracer: TracerSdk
    
    private init() {
        let spanExporter = JSONSpanExporter(logger: os.Logger.performance, isDebug: true)
        #if DEBUG
        let spanProcessor = SimpleSpanProcessor(spanExporter: spanExporter)
        #else
        let spanProcessor = BatchSpanProcessor(spanExporter: spanExporter)
        #endif

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
        name: String? = nil,
        _ attrs: [String: Any]? = nil,
        operation: (_ span: any SpanBase) throws -> T
    ) rethrows -> T {
        var spanName = name
        if spanName == nil {
            let fileName = (file as NSString).lastPathComponent.components(separatedBy: ".").first ?? "UnknownFile"
            let methodName = function
            spanName = "\(fileName).\(methodName)"
        }
        let extraText = "{\(String(describing: attrs?.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")))}"
        // 转换属性
        let convertedAttrs: [String: AttributeValue]? = attrs?.mapValues { value in
            switch value {
            case let string as String: return .string(string)
            case let int as Int: return .int(int)
            case let double as Double: return .double(double)
            case let bool as Bool: return .bool(bool)
            case let stringArray as [String]: return .stringArray(stringArray)
            case let intArray as [Int]: return .intArray(intArray)
            case let doubleArray as [Double]: return .doubleArray(doubleArray)
            case let boolArray as [Bool]: return .boolArray(boolArray)
            default: return .string(String(describing: value))
            }
        }
        
        let span = tracer.spanBuilder(spanName: spanName!)
        
        return try span.withActiveSpan { span in
            if let convertedAttrs = convertedAttrs {
                span.setAttributes(convertedAttrs)
            }
            
            defer {
                let end = CACurrentMediaTime()
            }
            return try operation(span)
        }
    }
    
    static var shared = Performance()
}
