//
//  HomeVC.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 28/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import RevealingSplashView
import Firebase
import Contacts
import AddressBookUI

class HomeVC: UIViewController, Alertable {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    
    var delegate: CenterVCDelegate?
    
    var manager : CLLocationManager!
    
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    
    var tableView = UITableView()
    
    var matchingItems: [MKMapItem] = [MKMapItem]()
    
    var route: MKRoute!
    
    var selectedItemPlacemark: MKPlacemark? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CLLocationManager()
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        
        checkLocationAuthStatus()
        
        mapView.delegate = self
        
        destinationTextField.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            
            self.centerMapOnUserLocation()
            
            DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
                self.loadDriverAnnotationsFromFB()
            })
        }
        
        
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        revealingSplashView.heartAttack = true
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.desiredAccuracy = kCLLocationAccuracyBest
            manager?.startUpdatingLocation()
        } else {
            manager?.requestAlwaysAuthorization()
        }
    }
    
    func loadDriverAnnotationsFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild("userIsDriver"){
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                                if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                    let coordinateArray = driverDict["coordinate"] as! NSArray
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)
                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                    
                                    var driverIsVisible: Bool {
                                        return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                    return true
                                                }
                                            }
                                            return false
                                        })
                                    }
                                    
                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                for annotation in self.mapView.annotations {
                                    if annotation.isKind(of: DriverAnnotation.self) {
                                        if let annotation = annotation as? DriverAnnotation {
                                            if annotation.key == driver.key {
                                                self.mapView.removeAnnotation(annotation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegion.init(center: mapView.userLocation.coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    @IBAction func actionBtnWasPressed(_ sender: Any) {
        actionBtn.animateButton(shouldLoad: true, withMessage: nil)
    }
    @IBAction func menuBtnWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel()
    }
    
    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        let currentUserId = Auth.auth().currentUser?.uid
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == currentUserId {
                        if user.hasChild("tripCoordinates") {
                            self.zoom(toFitAnnotationFromMapView: self.mapView)
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        } else {
                            self.centerMapOnUserLocation()
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        }
                    }
                }
            }
        })
    }
}

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            checkLocationAuthStatus()
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
}

extension HomeVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")
            return view
        } else if let annotation = annotation as? PassengerAnnotation {
            let identifier = "passenger"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "currentLocationAnnotation")
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: "destinationAnnotation")
            return annotationView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(overlay: self.route.polyline)
        lineRenderer.strokeColor = UIColor(displayP3Red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRenderer.lineWidth = 3
        
        zoom(toFitAnnotationFromMapView: mapView)
        return lineRenderer
    }
    
    func performSearch() {
        
        matchingItems.removeAll()
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        
        search.start { (response, error) in
            if (error != nil) {
                self.shouldPresentLoadingView(false)
                self.showAlert("There was an error while seraching for results, please try again.")
                print("Search error \(String(describing: error))")
            } else {
                if response?.mapItems.count == 0 {
                    self.shouldPresentLoadingView(false)
                    self.showAlert("There were no results. Please refine your search and try again.")
                    print("No results")
                } else {
                    for mapItem in (response?.mapItems)! {
                        self.matchingItems.append(mapItem as MKMapItem)
                    }
                    self.tableView.reloadData()
                    self.shouldPresentLoadingView(false)
                }
            }
        }
    }
    
    func dropPinFor(placemark: MKPlacemark) {
        selectedItemPlacemark = placemark
        
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func searchMapKitForResultsWithPolyline(forMapItem mapItem: MKMapItem) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert("Sorry but we couldn't find a proper route, please try again")
                print("Error calculating route, \(error.debugDescription)")
                return
            }
            self.route = response.routes[0]
            self.mapView.addOverlay(self.route.polyline)
            self.shouldPresentLoadingView(false)
        }
    }
    
    func zoom(toFitAnnotationFromMapView mapView: MKMapView) {
        if mapView.annotations.count != 0 {
            var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
            var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)
            
            for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
                topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
            }
            
            var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5 ), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))
            
            region = mapView.regionThatFits(region)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func retriveAddressDetails(mapItem : MKMapItem) -> String {
        var address = ""
        if let placeMark = mapItem.placemark as CLPlacemark? {
            if #available(iOS 11.0, *) {
                address = "\(placeMark.postalAddress!.street), \(placeMark.postalAddress!.city)"
            } else {
                address = ABCreateStringWithAddressDictionary(placeMark.addressDictionary!, false)
            }
        }
        return address
    }
}

extension HomeVC: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            tableView.frame = CGRect(x: 16, y: self.view.frame.height, width: self.view.frame.width - 32 , height: self.view.frame.height - 190)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")
            
            tableView.delegate = self
            tableView.dataSource = self
            
            tableView.tag = 18
            tableView.rowHeight = 60
            
            view.addSubview(tableView)
            animateTableView(shouldShow: true)
            
            UIView.animate(withDuration: 0.2) {
                self.destinationCircle.backgroundColor = UIColor.red
                self.destinationCircle.borderColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
            shouldPresentLoadingView(true)
            performSearch()
            view.endEditing(true)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircle.backgroundColor = UIColor.init(red: 154/255, green: 154/255, blue: 154/255, alpha: 1)
                    self.destinationCircle.borderColor = UIColor.init(red: 79/255, green: 79/255, blue: 79/255, alpha: 1.0)
                }
            }
        }
    }
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
            matchingItems.removeAll()
            tableView.reloadData()
            let currentUserId = Auth.auth().currentUser?.uid
            
            DataService.instance.REF_USERS.child(currentUserId!).child("tripCoordinates").removeValue()
            
            mapView.removeOverlays(mapView.overlays)
            for annotation in mapView.annotations {
                if let annotation = annotation as? MKPointAnnotation {
                    mapView.removeAnnotation(annotation)
                } else if annotation.isKind(of: PassengerAnnotation.self) {
                    mapView.removeAnnotation(annotation)
                }
            }
            centerMapOnUserLocation()
        }
        return true
    }
    
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 16, y: 190, width: self.view.frame.width - 32 , height: self.view.frame.height - 190)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 16, y: self.view.frame.height, width: self.view.frame.width - 32 , height: self.view.frame.height - 190)
            }, completion: { (finished) in
                for subview in self.view.subviews {
                    if subview.tag == 18 {
                        subview.removeFromSuperview()
                    }
                }
            })
        }
    }
}

extension HomeVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell", for: indexPath)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = retriveAddressDetails(mapItem: mapItem)
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresentLoadingView(true)
        let currentUserId = Auth.auth().currentUser?.uid
        let passengerCoordinate = manager?.location?.coordinate
        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate!, key: (currentUserId)!)
        mapView.addAnnotation(passengerAnnotation)
        
        let mapItem = matchingItems[indexPath.row]
        destinationTextField.text = mapItem.name
        
        let selectedResult = matchingItems[indexPath.row]
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues(["tripCoordinates": [selectedResult.placemark.coordinate.latitude, selectedResult.placemark.coordinate.longitude]])
        dropPinFor(placemark: selectedResult.placemark)
        searchMapKitForResultsWithPolyline(forMapItem: mapItem)
        print ("Selected")
        animateTableView(shouldShow: false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            for annotation in mapView.annotations {
                if annotation.isKind(of: MKPointAnnotation.self) {
                    mapView.removeAnnotation(annotation)
                }
            }
            animateTableView(shouldShow: false)
        }
    }
}

