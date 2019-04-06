//
//  ViewController.swift
//  auth0DeviceFlow
//
//  Created by Pushp Abrol on 8/21/18.
//  Copyright © 2018 Pushp Abrol. All rights reserved.
//

import UIKit
import Alamofire
import AVFoundation
import AVKit
class ViewController: UIViewController {
    
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var deleteTokenButton: UIButton!
    @IBAction func deleteToken(_ sender: UIButton) {
        
        UserDefaults.standard.removeObject(forKey: "access_token")
        self.setLoggedOutState()
    }
    @IBAction func playVideoAction(_ sender: UIButton) {
        
        self.checkToken { success in
            if(success) {
                guard let url = URL(string: "https://embed-ssl.wistia.com/deliveries/129e3bcb7f75083d6a0cb7213b0f2eefeae64680/file.mp4") else {
                    return
                }
                
                // Create an AVPlayer, passing it the HTTP Live Streaming URL.
                let player = AVPlayer(url: url)
                
                // Create a new AVPlayerViewController and pass it a reference to the player.
                let controller = AVPlayerViewController()
                controller.player = player
                
                // Modally present the player and call the player's play() method when complete.
                self.present(controller, animated: true) {
                    player.play()
                }
            }
            else {
                
                let alertController = UIAlertController(title: "Error", message: "Expired or invalid token!", preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                {
                    (result : UIAlertAction) -> Void in
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                self.setLoggedOutState()
                return
            }
            
            
        }
        
        
    }
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var urlAndCode: UILabel!
    var timer:Timer!
    var ClientId :String?
    var Domain: String?
    var GrantType: String?
    var countDown:Timer!
    var RTGrantType:String?
    
    
    @IBAction func startLogin(_ sender: UIButton) {
        self.loginButton.isHidden = true
        startDeviceCodeFlow(completion: {
            json,err in
            
            guard err == nil else {
                let alertController = UIAlertController(title: "Error", message: err, preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                {
                    (result : UIAlertAction) -> Void in
                    
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                self.setLoggedOutState()
                return
                
            }
            
            if((json?["error"]) != nil)
            {
                let alertController = UIAlertController(title: "Error", message: json?["error_description"] as? String, preferredStyle: UIAlertControllerStyle.alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                {
                    (result : UIAlertAction) -> Void in
                    
                }
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
                self.setLoggedOutState()
                
            }
            else
            {
                
                self.urlAndCode.text = "Sign In \n Get better video recommendations, watch your playlists and authsome videos. \n On your phone tablet or computer, go to \n ".appending(json?["verification_uri"] as! String).appending("\n and enter \n ").appending(json?["user_code"] as! String)
                var interval = json?["interval"] as! NSNumber;
                let interValvalue = interval.intValue + 1
                interval = interValvalue as NSNumber
                let t = TimeInterval.init(truncating: interval)
                let validFor = json?["expires_in"] as! Int
                self.countDown = Timer.scheduledTimer(timeInterval: TimeInterval(validFor), target: self, selector: #selector(self.onTimerFires), userInfo: nil, repeats: true)
                self.timer = self.setInterval(interval: t, block: { () -> Void in
                    self.checkDeviceVerification(device_code: json?["device_code"] as! String)
                    
                })
            }
            
        })
    }
    
    func startDeviceCodeFlow(completion: @escaping ([String: AnyObject]?, String?) -> Void){
        
        let oAuthEndpoint: String = "https://".appending(self.Domain!).appending("/oauth/device/code");
        let authRequest = ["client_id":self.ClientId,"scope": "openid profile email"] as! Dictionary<String,String>
        Alamofire.request(oAuthEndpoint , method: .post, parameters: authRequest, encoding: JSONEncoding.default)
            .responseJSON { response in
                guard response.error == nil else {
                    completion(nil, response.error?.localizedDescription)
                    return
                }
                
                // make sure we got JSON and it's a dictionary
                guard let json = response.result.value as? [String: AnyObject] else {
                    print("didn't get response yet!")
                    completion(nil, nil)
                    return
                }
                
                completion(json, nil)
                return
                
        }
        
        
    }
    
    @objc func onTimerFires()
    {
        
        self.timer.invalidate()
        self.countDown.invalidate()
        self.urlAndCode.text = "Timed out waiting for activation"
        self.loginButton.isHidden = false
        self.deleteTokenButton.isHidden = true
        
    }
    
    func setLoggedInState(){
        self.playButton.isHidden = false
        self.loginButton.isHidden = true
        self.playButton.isSelected = true
        self.deleteTokenButton.isHidden = false
        
    }
    
    func setLoggedOutState(){
        self.playButton.isHidden = true
        self.loginButton.isHidden = false
        self.loginButton.isEnabled = true
        self.loginButton.isSelected = true
        self.deleteTokenButton.isHidden = true
        self.urlAndCode.text = ""
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let path = Bundle.main.path(forResource: "Auth0", ofType: "plist")
        let dict = NSDictionary(contentsOfFile: path!)!
        self.ClientId = dict.object(forKey: "ClientId") as? String
        self.Domain = dict.object(forKey: "Domain") as? String
        self.GrantType = dict.object(forKey: "grant_type") as? String
        self.RTGrantType = dict.object(forKey: "rtGrantType") as? String
        self.loginButton.isHidden = true
        
        self.checkToken { success in
            if(success){
                self.setLoggedInState()
                self.playButton.sendAction(#selector(ViewController.playVideoAction), to: nil, for: nil)
            }
            else{
                self.getResponseUsingRefreshToken(refresh_token: UserDefaults.standard.object(forKey: "refresh_token") as! String, completion: {
                    responseJson in
                    guard responseJson != nil && responseJson!["error"] == nil else {
                        
                        let alertController = UIAlertController(title: "Error", message: "Token Expired, sign in again!", preferredStyle: UIAlertControllerStyle.alert)
                        
                        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                        {
                            (result : UIAlertAction) -> Void in
                            
                        }
                        UserDefaults.standard.removeObject(forKey: "access_token")
                        UserDefaults.standard.removeObject(forKey: "refresh_token")
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                        self.loginButton.isHidden = false
                        self.playButton.isHidden = true
                        self.deleteTokenButton.isHidden = true
                        
                        return
                    }
                    
                    for (key, value) in responseJson! {
                        print("key \(key) value2 \(value)")
                        UserDefaults.standard.set(value as? String, forKey: key)
                    }
                    self.setLoggedInState()
                    self.playButton.sendAction(#selector(ViewController.playVideoAction), to: nil, for: nil)
                    
                })
                return
            }
        }
  
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setTimeout(delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }
    
    func setInterval(interval:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: interval, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }
    
    func getResponseUsingRefreshToken(refresh_token:String, completion: @escaping ([String: AnyObject]?) -> Void){
        let oAuthEndpoint: String = "https://".appending(self.Domain!).appending("/oauth/token");
        
        let authRequest = ["grant_type":self.RTGrantType,"refresh_token": refresh_token, "client_id":self.ClientId] as! Dictionary<String,String>
        Alamofire.request(oAuthEndpoint , method: .post, parameters: authRequest, encoding: JSONEncoding.default)
            .responseJSON { response in
                guard response.error == nil else {
                    if(response.error?.localizedDescription.contains("input data was nil"))!
                    {
                        completion(nil)
                        return
                    }
                    else
                    {
                        completion(nil)
                    }
                    return
                }
                // make sure we got JSON and it's a dictionary
                guard let json = response.result.value as? [String: AnyObject] else {
                    print("didn't get response yet!")
                    completion(nil)
                    return
                }
                
                completion(json)
                return
        }
    }
    
    func checkToken(completion: @escaping (Bool) -> Void){
        guard let accessToken = UserDefaults.standard.object(forKey: "access_token")
            as? String else {
                completion(false)
                return
        }
        let userInfo: String = "https://".appending(self.Domain!).appending("/userinfo");
        let url = URL(string: userInfo)!
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        Alamofire.request(urlRequest)
            .responseJSON { response in
                guard response.error == nil else {
                    completion(false)
                    return
                }
                // make sure we got JSON and it's a dictionary
                guard (response.result.value as? [String: AnyObject]) != nil else {
                    completion(false)
                    return
                }
                completion(true)
                return
        }
    }
    
    func checkDeviceVerification(device_code:String){
        let oAuthEndpoint: String = "https://".appending(self.Domain!).appending("/oauth/token");
        
        let authRequest = ["grant_type":self.GrantType,"device_code": device_code, "client_id":self.ClientId] as! Dictionary<String,String>
        Alamofire.request(oAuthEndpoint , method: .post, parameters: authRequest, encoding: JSONEncoding.default)
            .responseJSON { response in
                guard response.error == nil else {
                    if(response.error?.localizedDescription.contains("input data was nil"))!
                    {
                        
                    }
                    else
                    {
                        let alertController = UIAlertController(title: "Error", message: response.error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                        
                        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                        {
                            (result : UIAlertAction) -> Void in
                            
                        }
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
                    return
                }
                
                // make sure we got JSON and it's a dictionary
                guard let json = response.result.value as? [String: AnyObject] else {
                    print("didn't get response yet!")
                    return
                }
                
                if((json["error"]) != nil)
                {
                    print(json["error_description"] as? String ?? "");
                    
                    if(json["error"] as? String != "authorization_pending"){
                        let alertController = UIAlertController(title: "Error", message: response.error?.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                        
                        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default)
                        {
                            (result : UIAlertAction) -> Void in
                            
                        }
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                        self.timer.invalidate()
                        self.countDown.invalidate()
                        self.urlAndCode.text = "Error while activating device. Please try again"
                    }
                    
                }
                else
                {
                    for (key, value) in json {
                        print("key \(key) value2 \(value)")
                        UserDefaults.standard.set(value as? String, forKey: key)
                    }
                    
                    self.urlAndCode.text = "Device Activated"
                    self.timer.invalidate();
                    self.countDown.invalidate()
                    self.setLoggedInState()
                    self.playButton.sendAction(#selector(ViewController.playVideoAction), to: nil, for: nil)
                    
                }
        }
    }
    
}

