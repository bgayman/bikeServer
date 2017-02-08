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
import SwiftyJSON
import LoggerAPI
import CloudFoundryEnv
import KituraStencil
import Foundation

public class Controller {
    
    let router: Router
    let appEnv: AppEnv
    
    var port: Int {
        get { return appEnv.port }
    }
    
    var url: String {
        get { return appEnv.url }
    }
    
    init() throws {
        appEnv = try CloudFoundryEnv.getAppEnv()
        
        // All web apps need a Router instance to define routes
        router = Router()
                
        // Basic GET request
        router.get("/hello", handler: getHello)
        
        // Basic POST request
        router.post("/hello", handler: postHello)
        
        // JSON Get request
        router.get("/json", handler: getJSON)
        
        router.setDefault(templateEngine: StencilTemplateEngine())
        
        router.get("/")
        { request, response, next in
            defer{ next() }
            try response.render("home", context: [:])
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
            let json = networkJSON?.rawValue as? [String: Any]
            try response.render("networks", context: json ?? [:])
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
            guard let stationJSON = stationJSON(href: href) else { return }
            response.send(json: stationJSON)
        }
        
        router.get("stations/:id")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["id"] else { return }
            guard let stationJSON = stationJSON(href: href) else { return }
            var context = stationJSON.rawValue as? JSONDictionary
            guard let stationsDicts = stationJSON["network"]["stations"].rawValue as? [JSONDictionary] else { return }
            var stations = stationsDicts.flatMap(BikeStation.init)
            if let data = try? Data(contentsOf: timeZoneURL(lat: stationJSON["network"]["location"]["latitude"].doubleValue, long: stationJSON["network"]["location"]["longitude"].doubleValue))
            {
                let timeZoneJSON = JSON(data: data)
                context?["stations"] = stations.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
            }
            else
            {
                context?["stations"] = stations.map{ $0.jsonDict }
            }
            try response.render("multipleStations", context: context ?? [:])
        }
        
        router.get("network/:networkID/station/:stationID")
        { request, response, next in
            defer{ next() }
            guard let href = request.parameters["networkID"] else { return }
            guard let stationJSON = stationJSON(href: href) else { return }
            guard let stationID = request.parameters["stationID"] else { return }
            guard let stationsDicts = stationJSON["network"]["stations"].rawValue as? [JSONDictionary] else { return }
            var context = stationJSON.rawValue as? JSONDictionary
            var stations = stationsDicts.flatMap(BikeStation.init)
            stations = stations.filter({ $0.id == stationID })
            if let data = try? Data(contentsOf: timeZoneURL(lat: stationJSON["network"]["location"]["latitude"].doubleValue, long: stationJSON["network"]["location"]["longitude"].doubleValue))
            {
                let timeZoneJSON = JSON(data: data)
                context?["stations"] = stations.map{ $0.jsonDict(timeZoneID: timeZoneJSON["timeZoneId"].stringValue) }
            }
            else
            {
                context?["stations"] = stations.map{ $0.jsonDict }
            }
            try response.render("singleStation", context: context ?? [:])
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
        
        router.get("json/network/:href/lat/:lat/long/:long")
        { request, response, next in
            defer{ next() }
            guard let lat = Double(request.parameters["lat"] ?? "a"),
                  let long = Double(request.parameters["long"] ?? "a"),
                  let href = request.parameters["href"],
                  let network = network(for: href)
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
