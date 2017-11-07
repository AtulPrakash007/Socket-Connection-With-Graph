//
//  SocketIOManager.swift
//  Socket Connection
//
//  Created by Mac on 5/8/17.
//  Copyright © 2017 AtulPrakash. All rights reserved.
//

import Foundation
import UIKit

protocol SocketIOManagerDelegate{
    func fetchedNumber(_ number:String)
}

class SocketIOManager: NSObject {
    
    var delegate:SocketIOManagerDelegate?
    
    static let sharedInstance = SocketIOManager()
    
    var socket = SocketIOClient(socketURL: URL(string: kSocketUrl)!)
    
    override init() {
        super.init()
        
    }
    
    func establishConnection() {
        socket.connect()
    }
    
    func closeConnection() {
        socket.disconnect()
    }
    
    func fetchRandomNumber() -> Void {
        socket.nsp = kSocketNamespace
        socket.on(kSocketEvent) { dataArray, ack in
            print(dataArray)
            let number:String = "\(dataArray[0])"
            self.delegate?.fetchedNumber(number)
            if Int(number)! > 0 && Int(number)! < 10{
                self.saveNumberToDB(number: number)
            }
        }
    }
    
    func saveNumberToDB(number streamedNumber:String) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        let numberDB = StreamedNumber(context: context)
        numberDB.streamed_number = streamedNumber
        numberDB.number_date = NSDate()
        // Save the data to coredata
        
        (UIApplication.shared.delegate as! AppDelegate).saveContext()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "currentStreamedNumber"), object: streamedNumber)
    }
    
    
}
