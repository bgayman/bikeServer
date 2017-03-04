//
//  GBFSStationStatus.swift
//  BikeShare
//
//  Created by Brad G. on 2/25/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct GBFSStationStatus
{
    let stationID: String
    let numberOfBikesAvailable: Int
    let numberOfBikesDisabled: Int?
    let numberOfDocksAvailable: Int
    let numberOfDocksDisabled: Int?
    let isInstalled: Bool
    let isRenting: Bool
    let isReturning: Bool
    let lastReported: Date
    
    var jsonDict: JSONDictionary
    {
        return [
            "station_id": self.stationID,
            "num_bikes_available": self.numberOfBikesAvailable,
            "num_bikes_disabled": self.numberOfBikesDisabled ?? 0,
            "num_docks_available": self.numberOfDocksAvailable,
            "num_docks_disabled": self.numberOfDocksDisabled ?? 0,
            "is_installed": self.isInstalled,
            "is_renting": self.isRenting,
            "is_returning": self.isReturning,
            "last_reported": self.lastReported
        ]
    }
}

extension GBFSStationStatus
{
    init?(json: JSONDictionary)
    {
        guard let stationID = json["station_id"] as? String,
              let numberOfBikesAvailable = json["num_bikes_available"] as? Int,
              let numberOfDocksAvailable = json["num_docks_available"] as? Int,
              let isInstalled = json["is_installed"] as? Int,
              let isRenting = json["is_renting"] as? Int,
              let isReturning = json["is_returning"] as? Int,
              let lastReportedInt = json["last_reported"] as? Int
        else { return nil }
        self.stationID = stationID
        self.numberOfBikesAvailable = numberOfBikesAvailable
        self.numberOfDocksAvailable = numberOfDocksAvailable
        self.numberOfBikesDisabled = json["num_bikes_disabled"] as? Int
        self.numberOfDocksDisabled = json["num_docks_disabled"] as? Int
        self.isInstalled = isInstalled == 1
        self.isRenting = isRenting == 1
        self.isReturning = isReturning == 1
        self.lastReported = Date(timeIntervalSince1970: Double(lastReportedInt))
    }
}

