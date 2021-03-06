//
//  LoginVC.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 29/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit
import Firebase

class LoginVC: UIViewController, UITextFieldDelegate, Alertable {
    
    @IBOutlet weak var emailField: RoundedCornerTextField!
    @IBOutlet weak var passwordField: RoundedCornerTextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var authBtn: RoundedShadowButton!
    var isHidden = true

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return UIStatusBarAnimation.slide
    }
    
    override var prefersStatusBarHidden: Bool {
        return isHidden
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailField.delegate = self
        passwordField.delegate = self
        
        view.bindToKeyboard()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(sender:)))
        self.view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        isHidden = false
        animateStatusBar()
        
    }
    
    @objc func handleScreenTap(sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func authBtnWasPressed(_ sender: Any) {
        if emailField.text != nil && passwordField.text != nil {
            authBtn.animateButton(shouldLoad: true, withMessage: nil)
            self.view.endEditing(true)
            
            if let email = emailField.text, let password = passwordField.text {
                Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
                    if error == nil {
                        if let user = user {
                            if self.segmentedControl.selectedSegmentIndex == 0 {
                                let userData = [FB_PROVIDER: user.providerID] as [String: Any]
                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: false)
                            } else {
                                let userData = [FB_PROVIDER: user.providerID, USER_IS_DRIVER: true, ACCOUNT_PICKUP_MODE_ENABLED: false, DRIVER_IS_ON_TRIP: false] as [String: Any]
                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: true)
                            }
                        }
                        print("Email user authenticated successfully with Firebase")
                        AppDelegate.getAppDelegate().MenuContainerVC.homeVC.viewDidLoad()
                        AppDelegate.getAppDelegate().MenuContainerVC.homeVC.viewWillAppear(true)
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        if let errorCode = AuthErrorCode(rawValue: error!._code) {
                            switch errorCode {
                            case .wrongPassword:
                                self.showAlert(ERROR_MSG_WRONG_PASSWORD)
                            default:
                                self.showAlert(ERROR_MSG_UNEXPECTED_ERROR)
                            }
                            if errorCode != .wrongPassword {
                                Auth.auth().createUser(withEmail: email, password: password, completion: { (user, error) in
                                    if error != nil {
                                        if let errorCode = AuthErrorCode(rawValue: error!._code) {
                                            switch errorCode {
                                            case AuthErrorCode.invalidEmail:
                                                self.showAlert(ERROR_MSG_INVALID_EMAIL)
                                            case .emailAlreadyInUse:
                                                self.showAlert(ERROR_MSG_EMAIL_ALREADY_IN_USE)
                                            case .weakPassword:
                                                self.showAlert(ERROR_MSG_PASSWORD_TOO_SHORT)
                                            default:
                                                self.showAlert(ERROR_MSG_UNEXPECTED_ERROR)
                                            }
                                        }
                                    } else {
                                        if let user = user {
                                            if self.segmentedControl.selectedSegmentIndex == 0 {
                                                let userData = [FB_PROVIDER: user.providerID] as [String: Any]
                                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: false)
                                            } else {
                                                let userData = [FB_PROVIDER: user.providerID, USER_IS_DRIVER: true, ACCOUNT_PICKUP_MODE_ENABLED: false, DRIVER_IS_ON_TRIP: false] as [String: Any]
                                                DataService.instance.createFirebaseDBUser(uid: user.uid, userData: userData, isDriver: true)
                                            }
                                        }
                                        print("Successfully created a new user with Firebase")
                                        AppDelegate.getAppDelegate().MenuContainerVC.homeVC.viewDidLoad()
                                        AppDelegate.getAppDelegate().MenuContainerVC.homeVC.viewWillAppear(true)
                                        self.dismiss(animated: true, completion: nil)
                                    }
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    func animateStatusBar() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.setNeedsStatusBarAppearanceUpdate()
        })
    }
}
