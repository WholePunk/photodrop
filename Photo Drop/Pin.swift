//
//  DeveloperPin.swift
//  Find a Developer
//
//  Created by Bob Warwick on 2015-03-22.
//  Copyright (c) 2015 Whole Punk Creators. All rights reserved.
//

import UIKit

class Pin: NSObject, MKAnnotation {
   
    var coordinate: CLLocationCoordinate2D
    var key: String
    
    init(key: String) {
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.key = key
    }
    
}
