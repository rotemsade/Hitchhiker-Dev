//
//  LeftSidePanelVC.swift
//  Hitchhiker Dev
//
//  Created by rotem.sade on 29/09/2018.
//  Copyright © 2018 rotem.sade. All rights reserved.
//

import UIKit
import Firebase

class LeftSidePanelVC: UIViewController, Alertable {
    
    let appDelegate = AppDelegate.getAppDelegate()
    
    @IBOutlet weak var userEmailLbl: UILabel!
    @IBOutlet weak var userAccountTypeLbl: UILabel!
    @IBOutlet weak var userImageView: RoundImageView!
    @IBOutlet weak var loginOutBtn: UIButton!
    @IBOutlet weak var pickupModeLbl: UILabel!
    @IBOutlet weak var pickupModeSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        pickupModeSwitch.isOn = false
        pickupModeSwitch.isHidden = true
        pickupModeLbl.isHidden = true
        
        if Auth.auth().currentUser == nil {
            userEmailLbl.text = ""
            userAccountTypeLbl.text = ""
            userImageView.isHidden = true
            loginOutBtn.setTitle("Sign Up / Login", for: .normal)
        } else {
            userEmailLbl.text = Auth.auth().currentUser?.email
            userImageView.isHidden = false
            loginOutBtn.setTitle("Logout", for: .normal)
        }
        
        observePassengersAndDrivers()
        
    }
    
    func observePassengersAndDrivers() {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "PASSENGER"
                    }
                }
            }
        })
        
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    if snap.key == Auth.auth().currentUser?.uid {
                        self.userAccountTypeLbl.text = "DRIVER"
                        self.pickupModeSwitch.isHidden = false
                        self.pickupModeLbl.isHidden = false
                        
                        let switchStatus = snap.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool
                        if switchStatus {
                            self.pickupModeSwitch.isOn = true
                            self.pickupModeLbl.text = "PICKUP MODE ENABLED"
                        } else {
                            self.pickupModeSwitch.isOn = false
                            self.pickupModeLbl.text = "PICKUP MODE DISABLED"
                        }
                            
                    }
                }
            }
        })
    }
    
    @IBAction func switchWasToggled(_ sender: Any) {
        if pickupModeSwitch.isOn {
            pickupModeLbl.isHidden = false
            pickupModeLbl.text = "PICKUP MODE ENABLED"
            appDelegate.MenuContainerVC.toggleLeftPanel()
            let currentUserID = Auth.auth().currentUser?.uid
            DataService.instance.REF_DRIVERS.child(currentUserID!).updateChildValues(["isPickupModeEnabled" : true])
        } else {
            appDelegate.MenuContainerVC.toggleLeftPanel()
            let currentUserID = Auth.auth().currentUser?.uid
            pickupModeLbl.text = "PICKUP MODE DISABLED"
            DataService.instance.REF_DRIVERS.child(currentUserID!).updateChildValues(["isPickupModeEnabled" : false])
        }
    }
    
    @IBAction func signUpLoginBtnWasPressed(_ sender: UIButton) {
        if Auth.auth().currentUser == nil {
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as? LoginVC
            present(loginVC!, animated: true, completion: nil)
        } else {
                do {
                    try Auth.auth().signOut()
                    userEmailLbl.text = ""
                    userAccountTypeLbl.text = ""
                    userImageView.isHidden = true
                    pickupModeLbl.text = ""
                    pickupModeSwitch.isHidden = true
                    loginOutBtn.setTitle("Sign Up / Login", for: .normal)
                } catch (let error) {
                    showAlert("There was an error signing out! Please try again.")
                    print("There was an error signing out,\(error)")
                }
        }
    }
}

