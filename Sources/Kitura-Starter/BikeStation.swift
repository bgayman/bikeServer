//
//  BikeStation.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation
import SwiftyJSON

struct BikeStation
{
    let name: String
    let timestamp: Date
    let coordinates: Coordinates
    let freeBikes: Int?
    let emptySlots: Int?
    let id: String
    let address: String?
    var distance: Double?
    
    var statusDisplayText: String
    {
        guard let freeBikes = self.freeBikes,
            let emptySlots = self.emptySlots
            else { return "🤷‍♀️" }
        return "\(freeBikes) 🚲, \(emptySlots) 🆓"
    }
    
    var dateComponentText: String
    {
        let dateComponentString = Constants.displayDateFormatter.string(from: self.timestamp)
        return "Updated at \(dateComponentString)"
    }
    
    var distanceText: String
    {
        guard let distance = self.distance else { return "" }
        let string = String(format: "%.2f miles", (distance + 0.005))
        return string
    }
    
    var color: String
    {
        guard let freeBikes = self.freeBikes,
              let emptySlots = self.emptySlots
        else
        {
            return "orange"
        }
        let totalDocks = freeBikes + emptySlots
        if freeBikes == 0 || emptySlots == 0
        {
            return "red"
        }
        if Double(freeBikes) / Double(totalDocks) < 0.25
        {
            return "orange"
        }
        else if Double(emptySlots) / Double(totalDocks) < 0.10
        {
            return "orange"
        }
        return "green"
    }
    
    func dateText(timeZoneID: String) -> String
    {
        guard let timeZone = TimeZone(identifier: timeZoneID) else
        {
            let dateComponentString = Constants.displayDateFormatter.string(from: self.timestamp)
            return "Updated at \(dateComponentString)"
        }
        Constants.displayDateFormatter.timeZone = timeZone
        let dateComponentString = Constants.displayDateFormatter.string(from: self.timestamp)
        Constants.displayDateFormatter.timeZone = nil
        return "Updated at \(dateComponentString)"
    }
}

extension BikeStation
{
    init?(json: JSONDictionary)
    {
        guard let name = json["name"] as? String,
            let timeString = json["timestamp"] as? String,
            let timestamp = Constants.dateFormatter.date(from: timeString),
            let longitude = json["longitude"] as? Double,
            let latitude = json["latitude"] as? Double,
            let id = json["id"] as? String
            else
        {
            return nil
        }
        let emptySlots = json["empty_slots"] as? Int
        let freeBikes = json["free_bikes"] as? Int
        self.name = name
        self.coordinates = Coordinates(latitude: latitude, longitude: longitude)
        self.freeBikes = freeBikes
        self.emptySlots = emptySlots
        self.id = id
        if let extras = json["extra"] as? JSONDictionary
        {
            if let address = extras["address"] as? String
            {
                self.address = address
            }
            else
            {
                self.address = nil
            }
            if let lastUpdated = extras["last_updated"] as? Double
            {
                self.timestamp = Date(timeIntervalSince1970: lastUpdated)
            }
            else
            {
                self.timestamp = timestamp
            }
        }
        else
        {
            self.address = nil
            self.timestamp = timestamp
        }
    }
    
    var jsonDict: JSONDictionary
    {
        return ["name": self.name,
                "timestamp": Constants.dateFormatter.string(from: self.timestamp),
                "longitude": self.coordinates.longitude,
                "free_bikes": self.freeBikes ?? 0,
                "latitude": self.coordinates.latitude,
                "empty_slots": self.emptySlots ?? 0,
                "id": self.id,
                "status": self.statusDisplayText,
                "updated": self.dateComponentText,
                "distance": self.distanceText,
                "color": self.color,
                "address": self.address ?? ""
        ]
    }
    
    var json: JSON
    {
        return JSON(self.jsonDict)
    }
    
    func jsonDict(timeZoneID: String) -> JSONDictionary
    {
        var jsonDict = self.jsonDict
        jsonDict["updated"] = self.dateText(timeZoneID: timeZoneID)
        return jsonDict
    }
}

extension BikeStation: Equatable
{
    static func ==(lhs: BikeStation, rhs: BikeStation) -> Bool
    {
        return lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}

extension BikeStation: Hashable
{
    var hashValue: Int
    {
        return self.id.hashValue
    }
}
