//
//  ViewController.swift
//  Photo Drop
//
//  Created by Bob Warwick on 2015-05-05.
//  Copyright (c) 2015 Whole Punk Creators. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate {

    // MARK: - Setup
    
    let locationManager = CLLocationManager()
    let imagePicker = UIImagePickerController()
    var firebase: Firebase?
    var geofire: GeoFire?
    var regionQuery: GFRegionQuery?
    var foundQuery: GFCircleQuery?
    var annotations: Dictionary<String, Pin> = Dictionary(minimumCapacity: 8)

    var lastExchangeKeyFound: String?
    var lastExchangeLocationFound: CLLocation?
    var inExchange = false
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var foundImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.sourceType = .PhotoLibrary
        imagePicker.delegate = self
        
        firebase = Firebase(url: "https://sizzling-inferno-971.firebaseio.com/")
        geofire = GeoFire(firebaseRef: firebase!.childByAppendingPath("geo"))

        let gestureRecongnizer = UITapGestureRecognizer(target: self, action: Selector("hideImageView:"))
        foundImage.addGestureRecognizer(gestureRecongnizer)
        
    }
    
    // MARK: - Map Tracking
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.requestWhenInUseAuthorization()
        self.mapView.userLocation.addObserver(self, forKeyPath: "location", options: NSKeyValueObservingOptions(), context: nil)
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        if (self.mapView.showsUserLocation && self.mapView.userLocation.location != nil) {
            
            let span = MKCoordinateSpanMake(0.0125, 0.0125)
            let region = MKCoordinateRegion(center: self.mapView.userLocation.location.coordinate, span: span)
            self.mapView.setRegion(region, animated: true)

            if regionQuery == nil {
                regionQuery = geofire?.queryWithRegion(region)
                
                regionQuery!.observeEventType(GFEventTypeKeyEntered, withBlock: { (key: String!, location: CLLocation!) in
                    let annotation = Pin(key: key)
                    annotation.coordinate = location.coordinate
                    self.mapView.addAnnotation(annotation)
                    self.annotations[key] = annotation
                })
                
                regionQuery!.observeEventType(GFEventTypeKeyExited, withBlock: { (key: String!, location: CLLocation!) -> Void in
                    self.mapView.removeAnnotation(self.annotations[key])
                    self.annotations[key] = nil
                })
                
            }
            
            
            // We also want a query with an extremely limited span.  When a photo enters that region, we want to notify the user they can exchange.
            if foundQuery == nil {
                foundQuery = geofire?.queryAtLocation(self.mapView.userLocation.location, withRadius: 0.05)
                
                foundQuery!.observeEventType(GFEventTypeKeyEntered, withBlock: { (key: String!, location: CLLocation!) -> Void in
                    self.lastExchangeKeyFound = key
                    self.lastExchangeLocationFound = location
                    let foundAPhoto = UIAlertView(title: "You Found a Drop!", message: "You can view the photo by tapping exchange and providing a new photo.", delegate: self, cancelButtonTitle: "Not Here", otherButtonTitles: "Exchange")
                    foundAPhoto.show()
                })
                
            } else {
                foundQuery?.center = self.mapView.userLocation.location
            }
            
        }
        
    }
    
    // MARK: - Drop a Photo
    
    @IBAction func dropPhoto(sender: AnyObject) {
        self.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        self.dismissViewControllerAnimated(true, completion: nil)
        
        // Save the photo to Firebase
        let thumbnail = image.resizedImageWithContentMode(UIViewContentMode.ScaleAspectFit, bounds: CGSizeMake(400, 400), interpolationQuality:kCGInterpolationHigh)
        let imgData = UIImagePNGRepresentation(thumbnail)
        let base64EncodedImage = imgData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.allZeros)
        
        if inExchange {

            // Download the existing photo and show it
            firebase?.childByAppendingPath(lastExchangeKeyFound).observeEventType(.Value, withBlock: { (snapshot) -> Void in
                
                self.firebase?.childByAppendingPath(self.lastExchangeKeyFound).removeAllObservers()
                
                let existingImageInBase64 = snapshot.value as! String
                let existingImageData = NSData(base64EncodedString: existingImageInBase64, options: NSDataBase64DecodingOptions.allZeros)
                let image = UIImage(data: existingImageData!)
                
                self.foundImage.image = image
                self.foundImage.hidden = false
                UIView.animateWithDuration(0.5, animations: { () -> Void in
                    
                    self.foundImage.alpha = 1.0
                    
                    var layer = self.foundImage.layer
                    layer.shadowColor = UIColor.blackColor().CGColor
                    layer.shadowRadius = 10.0
                    layer.shadowOffset = CGSizeMake(10.0, 5.0)
                    layer.shadowOpacity = 0.8
                    
                })
                
                // Overwrite the existing photo
                let existingReference = self.firebase?.childByAppendingPath(self.lastExchangeKeyFound)
                existingReference?.setValue(base64EncodedImage)
                
                // Go back to the non-exchange flow
                self.inExchange = false
                
            })
            
        } else {

            let uniqueReference = firebase?.childByAutoId()
            uniqueReference!.setValue(base64EncodedImage)
            
            let key = uniqueReference?.key
            let location = mapView.userLocation.location
            geofire!.setLocation(mapView.userLocation.location, forKey: key)
                        
        }

    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
        inExchange = false
    }
    
    func hideImageView(sender: AnyObject?) {
        
        UIView.animateWithDuration(0.5, animations: { () -> Void in
            
            self.foundImage.alpha = 0.0
            
            var layer = self.foundImage.layer
            layer.shadowColor = UIColor.blackColor().CGColor
            layer.shadowRadius = 0.0
            layer.shadowOffset = CGSizeMake(0.0, 0.0)
            layer.shadowOpacity = 0.0

        }) { (bool) -> Void in
            
            self.foundImage.image = nil
            self.foundImage.hidden = true
            
        }
        
    }
    
    // MARK: - Exchange Dialog Delegate
    
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        
        if buttonIndex == 1 {
            inExchange = true
            self.dropPhoto(self)
        }
        
    }
    
}

