//
//  GBFSStationInformation.swift
//  BikeShare
//
//  Created by Brad G. on 2/15/17.
//  Copyright © 2017 B Gay. All rights reserved.
//

import Foundation

struct GBFSStationInformation
{
    let stationID: String
    let name: String
    let coordinates: Coordinates
    let shortName: String?
    let address: String?
    let crossStreet: String?
    let regionID: String?
    let postCode: String?
    let rentalMethods: [String]?
    let capacity: Int?
    var stationStatus: GBFSStationStatus? = nil
    
    var jsonDict: JSONDictionary
    {
        return [
            "station_id": self.stationID,
            "name": self.name,
            "short_name": self.shortName ?? "",
            "lat": self.coordinates.latitude,
            "lon": self.coordinates.longitude,
            "address": self.address ?? "",
            "cross_street": self.crossStreet ?? "",
            "region_id": self.regionID ?? "",
            "post_code": self.postCode ?? "",
            "rental_methods": self.rentalMethods ?? [],
            "capacity": self.capacity ?? 0,
            "stationStatus": self.stationStatus?.jsonDict ?? [:]
        ]
    }
}

extension GBFSStationInformation
{
    init?(json: JSONDictionary)
    {
        guard let stationID = json["station_id"] as? String,
              let name = json["name"] as? String,
              let lat = json["lat"] as? Double,
              let lon = json["lon"] as? Double else { return nil}
        self.stationID = stationID
        self.name = name
        self.coordinates = Coordinates(latitude: lat, longitude: lon)
        self.shortName = json["short_name"] as? String
        self.address = json["address"] as? String
        self.crossStreet = json["cross_street"] as? String
        self.regionID = json["region_id"] as? String
        self.postCode = json["post_code"] as? String
        self.rentalMethods = json["rental_methods"] as? [String]
        self.capacity = json["capacity"] as? Int
    }
}
