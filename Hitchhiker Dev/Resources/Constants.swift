//
//  Constants.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 11/10/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import Foundation

// Alertable
let ALERT_MSG_PREFIX = "Error:"
let ALERT_BUTTON_FACE = "OK"

// Account
let ACCOUNT_IS_DRIVER = "isDriver"
let ACCOUNT_PICKUP_MODE_ENABLED = "isPickupModeEnabled"
let ACCOUNT_TYPE_PASSENGER = "PASSENGER"
let ACCOUNT_TYPE_DRIVER = "DRIVER"

// Location
let COORDINATE = "coordinate"

// Trip
let TRIP_COORDINATES = "tripCoordinates"
let TRIP_IS_ACCEPTED = "tripIsAccepted"
let TRIP_IN_PROGRESS = "tripIsInProgress"

// User
let USER_PICKUP_COORDINATE = "pickupCoordinate"
let USER_DESTINATION_COORDINATE = "destinationCoordinate"
let USER_PASSENGER_KEY = "passengerKey"
let USER_IS_DRIVER = "userIsDriver"

// Driver
let DRIVER_KEY = "driverKey"
let DRIVER_IS_ON_TRIP = "driverIsOnTrip"

// Map Annotations
let ANNO_DRIVER = "driverAnnotation"
let ANNO_PICKUP = "currentLocationAnnotation"
let ANNO_DESTINATION = "destinationAnnotation"

// Map Identifiers
let IDENTIFIER_DRIVER = "driver"
let IDENTIFIER_PASSENGER = "passenger"
let IDENTIFIER_DESTINATION = "destination"
let IDENTIFIER_PICKUP_POINT = "pickupPoint"

// Map Regions
let REGION_PICKUP = "pickup"
let REGION_DESTINATION = "destination"

// Firebase
let FB_PROVIDER = "provider"
let FB_USERS = "users"
let FB_DRIVERS = "drivers"
let FB_TRIPS = "trips"

// Storyboard
let MAIN_STORYBOARD = "Main"

// ViewControllers
let VC_LEFT_PANEL = "LeftSidePanelVC"
let VC_HOME = "HomeVC"
let VC_LOGIN = "LoginVC"
let VC_PICKUP = "PickupVC"

// TableViewCells
let CELL_LOCATION = "locationCell"

// UI Messaging
let MSG_SIGN_UP_SIGN_IN = "Sign Up / Login"
let MSG_SIGN_OUT = "Sign Out"
let MSG_LOGOUT = "Logout"
let MSG_PICKUP_MODE_ENABLED = "PICKUP MODE ENABLED"
let MSG_PICKUP_MODE_DISABLED = "PICKUP MODE DISABLED"
let MSG_REQUEST_RIDE = "REQUEST RIDE"
let MSG_START_TRIP = "START TRIP"
let MSG_END_TRIP = "END TRIP"
let MSG_GET_DIRECTIONS = "GET DIRECTIONS"
let MSG_CANCEL_TRIP = "CANCEL TRIP"
let MSG_DRIVER_COMING = "DRIVER COMING"
let MSG_ON_TRIP = "ON TRIP"
let MSG_PASSENGER_PICKUP = "Passenger Pickup Point"
let MSG_PASSENGER_DESTINATION = "Passenger Destination"

// Error Messages
let ERROR_MSG_PREFIX = "Search error"
let ERROR_MSG_NO_MATCHES_FOUND = "There was an error while seraching for results, please try again!"
let ERROR_MSG_REFINE_SEARCH = "There were no results. Please refine your search and try again."
let ERROR_MSG_NO_ROUTES = "Sorry but we couldn't find a proper route, please try again"
let ERROR_MSG_INVALID_EMAIL = "Sorry, the email you've entered appears to be invalid. Please try another email."
let ERROR_MSG_EMAIL_ALREADY_IN_USE = "It appears that email is already in use by another user. Please try again."
let ERROR_MSG_WRONG_PASSWORD = "Whoops! That was the wrong password!. Please try again."
let ERROR_MSG_PASSWORD_TOO_SHORT = "The password must be 6 characters long or more."
let ERROR_MSG_UNEXPECTED_ERROR = "There has been an unexpected error. Please try again."
let ERROR_MSG_LOGOUT = "There was an error signing out! Please try again."

// Image Names
let IMG_LUANCH_SCREEN_ICON = "launchScreenIcon"
let IMG_DESTINATION_ANNOTAION = "destinationAnnotation"
