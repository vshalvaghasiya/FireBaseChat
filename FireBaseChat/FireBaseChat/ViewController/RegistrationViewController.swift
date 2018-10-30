//
//  RegistrationViewController.swift
//  FireBaseChat
//
//  Created by vishal on 08/12/17.
//  Copyright © 2017 vishal. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseAuth
class RegistrationViewController: UIViewController {

    @IBOutlet weak var emailIdTextField: UITextField!
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var passworTextField: UITextField!
    @IBOutlet weak var contactNumberTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    //MARK:- Button Click Events
    @IBAction func backButtonClick(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func submitButtonClick(_ sender: UIButton) {
        /*
        let vc  = self.storyboard?.instantiateViewController(withIdentifier: "LoginViewController") as! LoginViewController
        self.navigationController?.pushViewController(vc, animated: true)
 */
        self.signUP()
    }
    
    func signUP(){
        Auth.auth().createUser(withEmail: emailIdTextField.text!, password: passworTextField.text!) { (user, error) in
         print(user?.displayName)
        print(user?.email)
        }
    }
    
}
