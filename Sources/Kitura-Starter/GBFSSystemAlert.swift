//
//  GBFSSystemAlert.swift
//  BikeShare
//
//  Created by Brad G. on 2/13/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

enum GBFSSytemAlertType: String
{
    case systemClosure = "SYSTEM_CLOSURE"
    case stationClosure = "STATION_CLOSURE"
    case stationMove = "STATION_MOVE"
    case other = "OTHER"
    
    var displayText: String
    {
        switch self
        {
        case .systemClosure:
            return "System Closure"
        case .stationClosure:
            return "Station Closure"
        case .stationMove:
            return "Station Move"
        case .other:
            return "General Alert"
        }
    }
}

struct GBFSSystemAlert
{
    let alertID: String
    let type: GBFSSytemAlertType
    let startTime: Date?
    let endTime: Date?
    let stationIDs: [String]?
    let url: URL?
    let summary: String
    let description: String?
    var stations: [GBFSStationInformation]? = nil
}

extension GBFSSystemAlert
{
    init?(json: JSONDictionary)
    {
        guard let alertID = json["alert_id"] as? String,
              let typeString = json["type"] as? String,
              let type = GBFSSytemAlertType(rawValue: typeString),
              let summary = json["summary"] as? String
        else
        {
            return nil
        }
        self.alertID = alertID
        self.type = type
        self.summary = summary
        if let times = json["times"] as? JSONDictionary
        {
            if let startDouble = times["start"] as? Double
            {
                self.startTime = Date(timeIntervalSinceReferenceDate: startDouble)
            }
            else
            {
                self.startTime = nil
            }
            if let endDouble = times["end"] as? Double
            {
                self.endTime = Date(timeIntervalSinceReferenceDate: endDouble)
            }
            else
            {
                self.endTime = nil
            }
            
        }
        else
        {
            self.startTime = nil
            self.endTime = nil
        }
        self.stationIDs = json["station_ids"] as? [String]
        if let urlString = json["url"] as? String
        {
            self.url = URL(string: urlString)
        }
        else
        {
            self.url = nil
        }
        self.description = json["description"] as? String
    }
}
