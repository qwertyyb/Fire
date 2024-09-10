//
//  MainAppService.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation
import FireXPCService

let XPCServiceName = "com.qwertyyb.inputmethod.Fire.FireXPCService"

class MainAppServer: NSObject, NSXPCListenerDelegate {
    var proxy: FireXPCServiceProtocol?
    let listener: NSXPCListener
    let mainAppXPCService = MainAppXPCService()
    override init() {
        self.listener = NSXPCListener.anonymous()
        super.init()
        self.listener.delegate = self

        let connection = NSXPCConnection(serviceName: XPCServiceName)
        connection.remoteObjectInterface = NSXPCInterface(with: FireXPCServiceProtocol.self)
        connection.resume()
        if let proxy = connection.remoteObjectProxy as? FireXPCServiceProtocol {
            self.proxy = proxy
            proxy.setMainAppEndpoint(endpoint: self.listener.endpoint) { ret in
                NSLog("[MainAppService] setMainAppEndPoint reply: \(ret)")
            }
        }
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: MainAppXPCServiceProtocol.self)
        
        newConnection.exportedObject = mainAppXPCService

        newConnection.resume()

        return true
    }
    
    static let shared = MainAppServer()
}
