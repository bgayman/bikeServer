/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Kitura
import KituraSession
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv
import KituraStencil
import Foundation
import Dispatch

public class Controller {
    
    let router: Router
    let appEnv: AppEnv
    let dispatchTimer: DispatchSourceTimer
    
    let historyNetworks = ["citi-bike-nyc",
                           "santander-cycles",
                           "bay-area-bike-share",
                           "divvy",
                           "biketown",
                           "bixi-montreal",
                           "bixi-toronto",
                           "capital-bikeshare",
                           "metro-bike-share",
                           "velib",
                           "ecobici",
                           "bikerio",
                           "mobibikes",
                           "boise-greenbike",
                           "greenbikeslc",
                           "hubway",
                           "indego",
                           "denver"]
    
    var port: Int
    {
        get { return appEnv.port }
    }
    
    var url: String
    {
        get { return appEnv.url }
    }
    
    init() throws
    {
        let queue = DispatchQueue(label: "com.bradgayman.bikeshare")
        self.dispatchTimer = DispatchSource.makeTimerSource(queue: queue)
        appEnv = try CloudFoundryEnv.getAppEnv()
        
        // All web apps need a Router instance to define routes
        router = Router()
                
        // Basic GET request
        router.get("/hello", handler: getHello)
        
        // Basic POST request
        router.post("/hello", handler: postHello)
        
        // JSON Get request
        router.get("/json", handler: getJSON)
        
        self.dispatchTimer.scheduleRepeating(deadline: DispatchTime.now(), interval: DispatchTimeInterval.seconds(3600), leeway: DispatchTimeInterval.seconds(60))
        self.dispatchTimer.setEventHandler
        {
            self.historyNetworks.forEach { addStationStatusesToDatabase(networkID: $0) }
            
        }
        DispatchQueue(label: "com.bradgayman.bikeshare").asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(10))
        { [weak self] in
            self?.dispatchTimer.resume()
        }
        
        router.setDefault(templateEngine: StencilTemplateEngine())
        router.all(middleware: Session(secret: "c'est la vie"))
        
        router.get("/")
        { request, response, next in
            defer{ next() }
            try response.render("home", context: [:])
        }
        
        router.get("/historyNetworks")
        { request, response, next in
            defer{ next() }
            let json = JSON(self.historyNetworks)
            response.send(json: json)
        }
        
        router.get("/apple-app-site-association")
        { request, response, next in
            defer{ next() }
            let json = JSON(["applinks": ["apps":[], "details": [["appID": "8DDUQH2RUD.com.bradgayman.BikeShare", "paths": ["*"]]]]])
            response.send(json: json)
        }
        
        router.get("/networks")
        { request, response, next in
            defer{ next() }
            guard var networks = networks else { return }
            if let lat = request.session?["lat"].double,
               let long = request.session?["long"].double
            {
                networks = sortedNetworks(coordinates: Coordinates(latitude: lat, longitude: long), networks: networks)
            }
            var context = JSONDictionary()
            context["networks"] = networks.map { $0.jsonDict }
            try response.render("networks", context: context)
        }
        
        router.get("/networks/json")
        { request, response, next in
            defer{ next() }
            response.send(json: networkJSON ?? JSON([]))
        }
        
        router.get("stations/:id/json")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["id"] else { return }
            guard let stations = stations(href: href) else { return }
            var context = JSONDictionary()
            context["stations"] = stations.map{ $0.jsonDict }
            let stationJSON = JSON(context)
            response.send(json: stationJSON)
        }
        
        router.get("stations/:id")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["id"],
                let network = network(for: href)
                else { return }
            var context = JSONDictionary()
            guard var stations = stations(href: href) else { return }
            if let lat = request.session?["lat"].double,
               let long = request.session?["long"].double
            {
                stations = sortedStations(coordinates: Coordinates(latitude: lat, longitude: long), stations: stations)
            }
            context["network"] = network.jsonDict
            if let data = try? Data(contentsOf: timeZoneURL(lat: network.location.coordinates.latitude, long: network.location.coordinates.longitude))
            {
                let timeZoneJSON = JSON(data: data)
                context["stations"] = stations.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
            }
            else
            {
                context["stations"] = stations.map{ $0.jsonDict }
            }
            try response.render("multipleStations", context: context)
        }
        
        router.get("network/:networkID/station/:stationID")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["networkID"],
                let network = network(for: href),
                let stationID = request.parameters["stationID"]
                else { return }
            var context = JSONDictionary()
            context["network"] = network.jsonDict
            guard var stats = stations(href: href) else { return }
            stats = stats.filter({ $0.id == stationID })
            if let data = try? Data(contentsOf: timeZoneURL(lat: network.location.coordinates.latitude, long: network.location.coordinates.longitude))
            {
                let timeZoneJSON = JSON(data: data)
                context["stations"] = stats.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
            }
            else
            {
                context["stations"] = stats.map{ $0.jsonDict }
            }
            try response.render("singleStation", context: context)
        }
        
        router.get("network/:networkID/station/:stationID/history/json")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["networkID"],
                let network = network(for: href),
                let stationID = request.parameters["stationID"]
                else { return }
            var context = JSONDictionary()
            context["network"] = network.jsonDict
            guard var stats = stations(href: href) else { return }
            stats = stats.filter({ $0.id == stationID })
            if let data = try? Data(contentsOf: timeZoneURL(lat: network.location.coordinates.latitude, long: network.location.coordinates.longitude))
            {
                let timeZoneJSON = JSON(data: data)
                context["station"] = stats.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
            }
            else
            {
                context["station"] = stats.map { $0.jsonDict }
            }
            if let statuses = getStationStatusesFromDatabase(network: network, stationID: stationID)
            {
                context["statuses"] = statuses.map { $0.jsonDict }
            }
            let json = JSON(context)
            response.send(json: json)
        }
        
        router.get("json/lat/:lat/long/:long")
        { request, response, next in
            defer{ next() }
            guard let lat = Double(request.parameters["lat"] ?? "a") else { return }
            guard let long = Double(request.parameters["long"] ?? "a") else { return }
            let coordinates = Coordinates(latitude: lat, longitude: long)
            let (closeStations, network) = closebyStations(coordinates: coordinates)
            guard case (.some, .some) = (closeStations, network) else { return }
            var jsonDict: JSONDictionary = ["network": network!.jsonDict]
            let closeDict: [JSONDictionary] = closeStations!.map{ $0.jsonDict }
            jsonDict["stations"] = closeDict
            let json = JSON(jsonDict)
            response.send(json: json)
        }
        
        router.get("systemInfo/:networkID")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["networkID"],
                let network = network(for: href),
                let feeds = feeds(gbfsHref: network.gbfsHref)
            else { return }
            guard var context = systemInformation(feeds: feeds)?.jsonDict else { return }
            context["network"] = network.jsonDict
            context["pricePlan"] = systemPricingPlan(feeds: feeds)
            context["alerts"] = systemAlert(feeds: feeds)
            try response.render("systemInfo", context: context)
        }
        
        router.get("json/network/:id/lat/:lat/long/:long")
        { request, response, next in
            defer{ next() }
            
            guard let lat = Double(request.parameters["lat"] ?? "a"),
                  let long = Double(request.parameters["long"] ?? "a"),
                  let networkID = request.parameters["id"],
                  let network = network(for: networkID)
            else { return }
            let coordinates = Coordinates(latitude: lat, longitude: long)
            let closeStations = closebyStations(coordinates: coordinates, network: network)
            guard closeStations != nil else { return }
            var jsonDict: JSONDictionary = ["network": network.jsonDict]
            let closeDict: [JSONDictionary] = closeStations!.map{ $0.jsonDict }
            jsonDict["stations"] = closeDict
            let json = JSON(jsonDict)
            response.send(json: json)
        }
        
        router.get("json/lat/:lat/long/:long")
        { request, response, next in
            defer{ next() }
            guard let lat = Double(request.parameters["lat"] ?? "a") else { return }
            guard let long = Double(request.parameters["long"] ?? "a") else { return }
            let coordinates = Coordinates(latitude: lat, longitude: long)
            let (closeStations, network) = closebyStations(coordinates: coordinates)
            guard case (.some, .some) = (closeStations, network) else { return }
            var jsonDict: JSONDictionary = ["network": network!.jsonDict]
            let closeDict: [JSONDictionary] = closeStations!.map{ $0.jsonDict }
            jsonDict["stations"] = closeDict
            let json = JSON(jsonDict)
            response.send(json: json)
        }
        
        router.all("/static", middleware: StaticFileServer())
        
        router.get("/lat/:lat/long/:long")
        { request, response, next in
            defer{ next() }
            guard let lat = Double(request.parameters["lat"] ?? "a") else { return }
            guard let long = Double(request.parameters["long"] ?? "a") else { return }
            
            request.session?["lat"].double = lat
            request.session?["long"].double = long
            
            let coordinates = Coordinates(latitude: lat, longitude: long)
            let json = closebyStationsJSON(coordinates: coordinates)
            let context = json.rawValue as? [String: Any]
            try response.render("multipleStations", context: context ?? [:])
        }

    }
    
    public func getHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("GET - /hello route handler...")
        response.headers["Content-Type"] = "text/plain; charset=utf-8"
        try response.status(.OK).send("Hello from Kitura-Starter!").end()
    }
    
    public func postHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("POST - /hello route handler...")
        response.headers["Content-Type"] = "text/plain; charset=utf-8"
        if let name = try request.readString() {
            try response.status(.OK).send("Hello \(name), from Kitura-Starter!").end()
        } else {
            try response.status(.OK).send("Kitura-Starter received a POST request!").end()
        }
    }
    
    public func getJSON(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
        Log.debug("GET - /json route handler...")
        response.headers["Content-Type"] = "application/json; charset=utf-8"
        var jsonResponse = JSON([:])
        jsonResponse["framework"].stringValue = "Kitura"
        jsonResponse["applicationName"].stringValue = "Kitura-Starter"
        jsonResponse["company"].stringValue = "IBM"
        jsonResponse["organization"].stringValue = "Swift @ IBM"
        jsonResponse["location"].stringValue = "Austin, Texas"
        try response.status(.OK).send(json: jsonResponse).end()
    }
    
}
