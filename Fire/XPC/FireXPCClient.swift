//
//  FireXPCClient.swift
//  Fire
//
//  Created by 杨永榜 on 2024/9/10.
//

import Foundation
import FireXPCService

func connectToMainApp(callback: @escaping (MainAppXPCServiceProtocol) -> Void) {
    let connection = NSXPCConnection(serviceName: "com.qwertyyb.inputmethod.Fire.FireXPCService")
    connection.remoteObjectInterface = NSXPCInterface(with: FireXPCServiceProtocol.self)
    connection.resume()
    guard let connectProxy = connection.remoteObjectProxy as? FireXPCServiceProtocol else { return }

    connectProxy.getMainAppEndpoint { endpoint in
        let serverConnection = NSXPCConnection(listenerEndpoint: endpoint)
        serverConnection.remoteObjectInterface = NSXPCInterface(with: MainAppXPCServiceProtocol.self)
        serverConnection.resume()
        guard let mainApp = serverConnection.remoteObjectProxy as? MainAppXPCServiceProtocol else { return }
        callback(mainApp)
    }
}
