//
//  BikeStationStatus.swift
//  Kitura-Starter
//
//  Created by B Gay on 4/15/17.
//
//

import Foundation
import Node

struct BikeStationStatus
{
    static let dateFormatter: DateFormatter =
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    let id: Int
    let stationID: String
    let networkID: String
    let timestamp: Date
    let numberOfBikesAvailable: Int
    let numberOfBikesDisabled: Int?
    let numberOfDocksAvailable: Int?
    let numberOfDocksDisabled: Int?
    let isInstalled: Bool?
    let isRenting: Bool?
    let isReturning: Bool?
    
    init?(node: [String: Node])
    {
        guard let id = node["statusID"]?.int,
              let stationID = node["stationID"]?.string,
              let networkID = node["networkID"]?.string,
              let timestampString = node["timestamp"]?.string,
              let timestamp = BikeStationStatus.dateFormatter.date(from: timestampString),
              let numberOfBikesAvailable = node["numberOfBikesAvailable"]?.int else { return nil }
        self.id = id
        self.stationID = stationID
        self.networkID = networkID
        self.timestamp = timestamp
        self.numberOfBikesAvailable = numberOfBikesAvailable
        self.numberOfBikesDisabled = node["numberOfBikesDisabled"]?.int
        self.numberOfDocksAvailable = node["numberOfDocksAvailable"]?.int
        self.numberOfDocksDisabled = node["numberOfDocksDisabled"]?.int
        self.isInstalled = node["isInstalled"]?.bool
        self.isRenting = node["isRenting"]?.bool
        self.isReturning = node["isReturning"]?.bool
    }
    
    var jsonDict: [String: Any]
    {
        var jsonDict: [String: Any]
                     = [ "statusID": self.id,
                         "stationID": self.stationID,
                         "networkID": self.networkID,
                         "timestamp": self.timestamp.timeIntervalSinceReferenceDate,
                         "numberOfBikesAvailable": self.numberOfBikesAvailable]
        if let numberOfBikesDisabled = self.numberOfDocksDisabled
        {
            jsonDict["numberOfBikesDisabled"] = numberOfBikesDisabled
        }
        if let numberOfDocksAvailable = self.numberOfDocksAvailable
        {
            jsonDict["numberOfDocksAvailable"] = numberOfDocksAvailable
        }
        if let numberOfDocksDisabled = self.numberOfDocksDisabled
        {
            jsonDict["numberOfDocksDisabled"] = numberOfDocksDisabled
        }
        if let isInstalled = self.isInstalled
        {
            jsonDict["isInstalled"] = isInstalled
        }
        if let isRenting = self.isRenting
        {
            jsonDict["isRenting"] = isRenting
        }
        if let isReturning = self.isReturning
        {
            jsonDict["isReturning"] = isReturning
        }
        return jsonDict
    }
}










