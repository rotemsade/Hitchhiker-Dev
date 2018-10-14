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

enum AnnotationType {
    case pickup
    case destination
    case driver
}

enum ButtonAction {
    case requestRide
    case getDirectionsToPassenger
    case getDirectionsToDestination
    case startTrip
    case endTrip
}

class HomeVC: UIViewController, Alertable {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var cancelTripBtn: UIButton!
    
    
    var delegate: CenterVCDelegate?
    
    var manager : CLLocationManager!
    
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: IMG_LUANCH_SCREEN_ICON)!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    
    var tableView = UITableView()
    
    var matchingItems: [MKMapItem] = [MKMapItem]()
    
    var route: MKRoute!
    
    var selectedItemPlacemark: MKPlacemark? = nil
    
    var actionForButton: ButtonAction = .requestRide
    
    var currentUserId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestAlwaysAuthorization()
        
        checkLocationAuthStatus()
        
        mapView.delegate = self
        
        destinationTextField.delegate = self
        
        centerMapOnUserLocation()
        
        cancelTripBtn.alpha = 0.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            
            self.currentUserId = Auth.auth().currentUser?.uid
            
            DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
                if let currentUserId = self.currentUserId {
                    self.loadDriverAnnotationsFromFB()
                    DataService.instance.passengerIsOnTrip(passengerKey: currentUserId, handler: { (isOnTrip, driverKey, tripKey) in
                        if isOnTrip == true {
                            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                        }
                    })
                }
            })
            
            if let currentUserId = self.currentUserId {
            
                UpdateService.instance.observeTrips(handler: { (tripDict) in
                    if let tripDict = tripDict {
                        let pickupCoordinateArray = tripDict[USER_PICKUP_COORDINATE] as! NSArray
                        let tripKey = tripDict[USER_PASSENGER_KEY] as! String
                        let acceptanceStatus = tripDict[TRIP_IS_ACCEPTED] as! Bool
                        
                        if acceptanceStatus == false {
                            DataService.instance.driverIsAvailable(key: currentUserId, handler: { (available) in
                                if let available = available {
                                    if available == true {
                                        let storyboard = UIStoryboard(name: MAIN_STORYBOARD, bundle: Bundle.main)
                                        let pickupVC = storyboard.instantiateViewController(withIdentifier: VC_PICKUP) as? PickupVC
                                        pickupVC?.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees), passengerKey: tripKey)
                                        self.present(pickupVC!, animated: true, completion: nil)
                                    }
                                }
                            })
                        }
                    }
                })
            }
        }
        
        
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        if currentUserId == nil {
            revealingSplashView.heartAttack = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if self.currentUserId != nil {
                DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (status) in
                    if status == true {
                        self.buttonsForDriver(areHidden: true)
                    }
                })
                
                DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
                    let removedTripDict = removedTripSnapshot.value as? [String: AnyObject]
                    if removedTripDict?[DRIVER_KEY] != nil {
                        DataService.instance.REF_DRIVERS.child(removedTripDict?[DRIVER_KEY] as! String).updateChildValues([DRIVER_IS_ON_TRIP: false])
                    }
                    DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (isDriver) in
                        if isDriver {
                            self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                            self.buttonsForDriver(areHidden: true)
                            print("**************************Remove for a driver #1")
                        } else {
                            self.cancelTripBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                            self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_REQUEST_RIDE)
                            
                            self.destinationTextField.isUserInteractionEnabled = true
                            self.destinationTextField.text = ""
                            
                            self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                            print("*************************Remove for a passenger #2")
                            self.centerMapOnUserLocation()
                            
                        }
                    })
                })
                
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                            if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                                for trip in tripSnapshot {
                                    if trip.childSnapshot(forPath: DRIVER_KEY).value as? String == self.currentUserId {
                                        let pickupCoordinatesArray = trip.childSnapshot(forPath: USER_PICKUP_COORDINATE).value as! NSArray
                                        let pickupCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: pickupCoordinatesArray[0] as! CLLocationDegrees, longitude: pickupCoordinatesArray[1] as! CLLocationDegrees)
                                        let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                        
                                        self.dropPinFor(placemark: pickupPlacemark)
                                        print("*****************************Drop pin #1 at (\(pickupPlacemark.coordinate.latitude),\(pickupPlacemark.coordinate.longitude))")
                                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                        
                                        self.setCustomRegion(forAnnotationType: .pickup, withCoordinate: pickupCoordinate)
                                        
                                        self.actionForButton = .getDirectionsToPassenger
                                        self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                                        
                                        self.buttonsForDriver(areHidden: false)
                                    }
                                }
                            }
                        })
                    }
                })
                
                self.connectUserAndDriverForTrip()
                
            }
        }
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.desiredAccuracy = kCLLocationAccuracyBest
            manager?.startUpdatingLocation()
        } else {
            manager?.requestAlwaysAuthorization()
        }
    }
    
    func buttonsForDriver(areHidden: Bool) {
        if areHidden {
            self.actionBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.cancelTripBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.actionBtn.isHidden = true
            self.cancelTripBtn.isHidden = true
            self.centerMapBtn.isHidden = true
        } else {
            self.actionBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.cancelTripBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.actionBtn.isHidden = false
            self.cancelTripBtn.isHidden = false
            self.centerMapBtn.isHidden = false
        }
    }
    
    func loadDriverAnnotationsFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild(COORDINATE) {
                        if driver.childSnapshot(forPath: ACCOUNT_PICKUP_MODE_ENABLED).value as? Bool == true {
                            if let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                let coordinateArray = driverDict[COORDINATE] as! NSArray
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
        })
        revealingSplashView.heartAttack = true
    }
    
    func connectUserAndDriverForTrip() {
        print("*****************connectUserAndDriverForTrip was called")
        DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            print ("isOnTrip: \(String(describing: isOnTrip)) driver: \(String(describing: driverKey)) trip: \(String(describing: tripKey))")
            if isOnTrip == true {
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                print("***********Remove  #3")
                
                DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                    let driverId = tripDict?[DRIVER_KEY] as! String
                    
                    let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                    let pickupMapItem = MKMapItem(placemark: pickupPlacemark)
                    
                    DataService.instance.REF_DRIVERS.child(driverId).child(COORDINATE).observeSingleEvent(of: .value, with: { (coordinateSnapshot) in
                        let coordinateSnapshot = coordinateSnapshot.value as! NSArray
                        let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateSnapshot[0] as! CLLocationDegrees, longitude: coordinateSnapshot[1] as! CLLocationDegrees)
                        let driverPlacemark = MKPlacemark(coordinate: driverCoordinate)
                        let driverMapItem = MKMapItem(placemark: driverPlacemark)
                        
                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
                        self.mapView.addAnnotation(passengerAnnotation)
                        
                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
                        self.actionBtn.animateButton(shouldLoad: false, withMessage: MSG_DRIVER_COMING)
                        self.actionBtn.isUserInteractionEnabled = false
                    })
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                        if tripDict?[TRIP_IN_PROGRESS] as? Bool == true {
                            self.removeOverlaysAndAnnotations(forDrivers: true, forPassengers: true)
                            print("*********************Remove #4")
                            
                            let destinationCoordinateArray = tripDict?[USER_DESTINATION_COORDINATE] as! NSArray
                            let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                            
                            let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                            let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                            let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                            let pickupAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
                            self.mapView.addAnnotation(pickupAnnotation)
                            
                            self.dropPinFor(placemark: destinationPlacemark)
                            print("*********************Drop pin #2 at (\(destinationPlacemark.coordinate.latitude),\(destinationPlacemark.coordinate.longitude))")
                            
                            self.searchMapKitForResultsWithPolyline(forOriginMapItem: MKMapItem(placemark: pickupPlacemark), withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                            
                            self.actionBtn.setTitle(MSG_ON_TRIP, for: .normal)
                        }
                    })
                    
                })
            }
        })
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegion.init(center: mapView.userLocation.coordinate, latitudinalMeters: regionRadius * 2.0, longitudinalMeters: regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    //MARK: - IBActions
    
    @IBAction func actionBtnWasPressed(_ sender: Any) {
        buttonSelector(forAction: actionForButton)
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
            }
        }
        
        DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: driverKey!)
                print("************************Button canceled pressed pass on a trip")
            } else {
                self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                print("************************Remove #5")
                self.centerMapOnUserLocation()
            }
        }
        actionBtn.isUserInteractionEnabled = true
    }
    
    @IBAction func menuBtnWasPressed(_ sender: UIButton) {
        delegate?.toggleLeftPanel()
    }
    
    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        let currentUserId = self.currentUserId
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == currentUserId {
                        if user.hasChild(TRIP_COORDINATES) {
                            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
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
    
    func buttonSelector(forAction action: ButtonAction) {
        switch action {
        case .requestRide:
            if destinationTextField.text != "" {
                UpdateService.instance.updateTripsWithCoordinatesUponRequest()
                actionBtn.animateButton(shouldLoad: true, withMessage: nil)
                cancelTripBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
                
                self.view.endEditing(true)
                destinationTextField.isUserInteractionEnabled = false
            }
        case .getDirectionsToPassenger:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).observe(.value, with: { (tripSnapshot) in
                        let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                        
                        let pickupCoordinateArray = tripDict?[USER_PICKUP_COORDINATE] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupMapItem = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate))
                        
                        pickupMapItem.name = MSG_PASSENGER_PICKUP
                        pickupMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .startTrip:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: false)
                    print("************************Remove #6")
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).updateChildValues([TRIP_IN_PROGRESS: true])
                    
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observeSingleEvent(of: .value, with: { (coordinateSnapshot) in
                        let destinationCoordinateArray = coordinateSnapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        
                        self.dropPinFor(placemark: destinationPlacemark)
                        print("**************************Drop pin #3 at (\(destinationPlacemark.coordinate.latitude),\(destinationPlacemark.coordinate.longitude))")
                        
                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: destinationPlacemark))
                        self.setCustomRegion(forAnnotationType: .destination, withCoordinate: destinationCoordinate)
                        
                        self.actionForButton = .getDirectionsToDestination
                        self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                    })
                }
            })
        case .getDirectionsToDestination:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).child(USER_DESTINATION_COORDINATE).observe(.value, with: { (snapshot) in
                        
                        // CRASH
                        
                        let destinationCoordinateArray = snapshot.value as! NSArray
                        let destinationCoordinate = CLLocationCoordinate2D(latitude: destinationCoordinateArray[0] as! CLLocationDegrees, longitude: destinationCoordinateArray[1] as! CLLocationDegrees)
                        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
                        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
                        
                        destinationMapItem.name = MSG_PASSENGER_DESTINATION
                        destinationMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .endTrip:
            DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
                    self.buttonsForDriver(areHidden: true)
                }
            })
        }
    }
}

//MARK: - CLLocation Manager Delegate

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            checkLocationAuthStatus()
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip == true {
                if region.identifier == REGION_PICKUP {
                    self.actionForButton = .startTrip
                    self.actionBtn.setTitle(MSG_START_TRIP, for: .normal)
                } else if region.identifier == REGION_DESTINATION {
                    self.cancelTripBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.cancelTripBtn.isHidden = true
                    self.actionForButton = .endTrip
                    self.actionBtn.setTitle(MSG_END_TRIP, for: .normal)
                }
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                if region.identifier == REGION_PICKUP {
                    self.actionForButton = .getDirectionsToPassenger
                    self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                } else if region.identifier == REGION_DESTINATION {
                    self.actionForButton = .getDirectionsToDestination
                    self.actionBtn.setTitle(MSG_GET_DIRECTIONS, for: .normal)
                }
            }
        })
    }
}

//MARK: - MKMapView Delegate

extension HomeVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
        
        if let currentUserId = Auth.auth().currentUser?.uid {
            DataService.instance.userIsDriver(userKey: currentUserId) { (isDriver) in
                if isDriver == true {
                    DataService.instance.driverIsOnTrip(driverKey: currentUserId, handler: { (isOnTrip, driverKey, tripKey) in
                        if isOnTrip == true {
                            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                        } else {
                            self.centerMapOnUserLocation()
                        }
                    })
                } else {
                    DataService.instance.passengerIsOnTrip(passengerKey: currentUserId, handler: { (isOnTrip, driverKey, tripKey) in
                        if isOnTrip == true {
                            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                        } else {
                            self.centerMapOnUserLocation()
                        }
                    })
                }
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = IDENTIFIER_DRIVER
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNO_DRIVER)
            return view
        } else if let annotation = annotation as? PassengerAnnotation {
            let identifier = IDENTIFIER_PASSENGER
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: ANNO_PICKUP)
            return view
        } else if let annotation = annotation as? MKPointAnnotation {
            let identifier = IDENTIFIER_DESTINATION
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: ANNO_DESTINATION)
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
        
        shouldPresentLoadingView(false)
        
        zoom(toFitAnnotationFromMapView: mapView, forActiveTripWithDriver: false, withKey: nil)
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
                self.showAlert(ERROR_MSG_NO_MATCHES_FOUND)
                print("\(ERROR_MSG_PREFIX) \(String(describing: error))")
            } else {
                if response?.mapItems.count == 0 {
                    self.shouldPresentLoadingView(false)
                    self.showAlert(ERROR_MSG_REFINE_SEARCH)
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
                print("******************** In dropPinFor Remove annotation lat:\(annotation.coordinate.latitude) log:\(annotation.coordinate.longitude)")
                mapView.removeAnnotation(annotation)
            }
        }
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        print("******************** In dropPinFor Add annotation lat:\(annotation.coordinate.latitude) log:\(annotation.coordinate.longitude)")
        mapView.addAnnotation(annotation)
    }
    
    func searchMapKitForResultsWithPolyline(forOriginMapItem originMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        print("**********************searchMapKitForResultsWithPolyline")
        let request = MKDirections.Request()
        if originMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }
        request.destination = destinationMapItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert(ERROR_MSG_NO_ROUTES)
                print("Error calculating route, \(error.debugDescription)")
                return
            }
            self.route = response.routes[0]
            
            self.mapView.addOverlay(self.route.polyline)
            print("**********************Add overlay at origin coordinates:(\(request.source?.placemark.coordinate.latitude), \(request.source?.placemark.coordinate.longitude) and destination coordinates:(\(request.source?.placemark.coordinate.latitude),\(request.source?.placemark.coordinate.longitude))")
            
            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
            
            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
    }
    
    func zoom(toFitAnnotationFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?) {
        if mapView.annotations.count == 0 {
            return
        }
        
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)
            
        if forActiveTripWithDriver {
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                }
            }
        }
            
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
    
    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                print("********************Remove Destination Annotations log:\(annotation.coordinate.longitude) lat: \(annotation.coordinate.latitude)")
                mapView.removeAnnotation(annotation)
            }
            
            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    print("********************Remove Passenger Annotations log:\(annotation.coordinate.longitude) lat: \(annotation.coordinate.latitude)")
                    mapView.removeAnnotation(annotation)
                }
            }
            
            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    print("********************Remove Passenger Annotations log:\(annotation.coordinate.longitude) lat: \(annotation.coordinate.latitude)")
                    mapView.removeAnnotation(annotation)
                }
            }
        }
        
        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                print("********************Remove overlay log:\(overlay.coordinate.longitude) lat: \(overlay.coordinate.latitude)")
                mapView.removeOverlay(overlay)
            }
        }
    }
    
    func setCustomRegion(forAnnotationType type: AnnotationType, withCoordinate coordinate: CLLocationCoordinate2D) {
        if type == .pickup {
            let pickupRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: REGION_PICKUP)
            manager?.startMonitoring(for: pickupRegion)
        } else if type == .destination {
            let destinationRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: REGION_DESTINATION)
            manager?.startMonitoring(for: destinationRegion)
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

//MARK: - TextField Delegate

extension HomeVC: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            tableView.frame = CGRect(x: 16, y: self.view.frame.height, width: self.view.frame.width - 32 , height: self.view.frame.height - 190)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: CELL_LOCATION)
            
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
            
            DataService.instance.REF_USERS.child(currentUserId!).child(TRIP_COORDINATES).removeValue()
            
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

//MARK: - TableView Data Source & Delegate

extension HomeVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell", for: indexPath)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: CELL_LOCATION)
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
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues([TRIP_COORDINATES: [selectedResult.placemark.coordinate.latitude, selectedResult.placemark.coordinate.longitude]])
        dropPinFor(placemark: selectedResult.placemark)
        print("*************************Drop pin #4 at (\(selectedResult.placemark.coordinate.latitude),\(selectedResult.placemark.coordinate.longitude))")
        searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: selectedResult)
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

