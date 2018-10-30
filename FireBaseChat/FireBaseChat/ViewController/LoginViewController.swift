//
//  LoginViewController.swift
//  FireBaseChat
//
//  Created by vishal on 08/12/17.
//  Copyright © 2017 vishal. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseAuth
class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK:- Button Click Events
    @IBAction func loginButtonClick(_ sender: UIButton) {
        self.signIn()
    }
    
    @IBAction func registrationButtonClick(_ sender: UIButton) {
        let vc  = self.storyboard?.instantiateViewController(withIdentifier: "RegistrationViewController") as! RegistrationViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func signIn(){
        Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { (user, error) in
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "ChatViewController") as! ChatViewController
            print(user?.uid)
//            vc.userID = (user?.uid)!
//            vc.userName = (user?.displayName)!
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

}

