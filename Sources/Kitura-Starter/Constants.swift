//
//  Constants.swift
//  project1
//
//  Created by Brad G. on 1/2/17.
//
//

import Foundation

typealias JSONDictionary = [String: Any]

struct Constants
{
    static let dateFormatter: DateFormatter =
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }()
    
    static let dateComponentsFormatter: DateComponentsFormatter =
    {
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.unitsStyle = .full
        dateComponentsFormatter.includesApproximationPhrase = true
        dateComponentsFormatter.maximumUnitCount = 1
        dateComponentsFormatter.allowedUnits = [.month, .day, .hour, .minute, .second]
        return dateComponentsFormatter
    }()
    
    static let NetworkURL = URL(string: "https://api.citybik.es/v2/networks")!
    static let BaseURL = "https://api.citybik.es/v2/networks/"
    static let DidUpdatedUserLocationNotification = "DidUpdatedUserLocationNotification"
    static let AppGroupName = "group.com.bradgayman.bikeshare"
    static let HomeNetworkKey = "homeNetworkKey"
}
