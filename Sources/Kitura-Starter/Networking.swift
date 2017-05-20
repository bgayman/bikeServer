//
//  Networking.swift
//  Kitura-Starter
//
//  Created by B Gay on 5/20/17.
//
//

import Foundation
import KituraNet
import SwiftyJSON

func get(_ url: String) -> JSON?
{
    var responseBody = Data()
    let _ = HTTP.get(url)
    { (response) in
        if let response = response
        {
            guard response.statusCode == .OK else { return }
            do
            {
                _ = try? response.readAllData(into: &responseBody)
            }
            catch
            {
            
            }
        }
    }
    
    if responseBody.count > 0
    {
        let json = JSON(data: responseBody)
        return json
    }
    else
    {
        return nil
    }
}
