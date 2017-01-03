//
//  Coordinates.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation

struct Coordinates
{
    let latitude: Double
    let longitude: Double
}

extension Coordinates
{
    func distance(to coordinates: Coordinates) -> Double
    {
        let theta = self.longitude - coordinates.longitude
        var dist = sin(deg2rad(self.latitude)) * sin(deg2rad(coordinates.latitude)) + cos(deg2rad(self.latitude)) * cos(deg2rad(coordinates.latitude)) * cos(deg2rad(theta))
        dist = acos(dist)
        dist = rad2deg(dist)
        dist = dist * 60 * 1.1515
        return dist * 1.609344
    }
    
    func deg2rad(_ deg: Double) -> Double
    {
        return deg * Double.pi / 180
    }
    
    func rad2deg(_ rad: Double) -> Double
    {
        return rad * 180.0 / Double.pi
    }
}
