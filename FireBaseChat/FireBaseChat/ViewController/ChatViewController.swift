//
//  ChatViewController.swift
//  FireBaseChat
//
//  Created by vishal on 19/12/17.
//  Copyright © 2017 vishal. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Firebase
final class ChatViewController: JSQMessagesViewController {

    private let imageURLNotSetKey = "NOTSET"
    private var locationSetKey = "LOCATIONNOTSET"
    var userID : String = ""
    var channelRef: DatabaseReference = Database.database().reference()
//    var userObj : User = User()
    
    private lazy var messageRef: DatabaseReference = self.channelRef.child("messages")
    fileprivate lazy var storageRef: StorageReference = Storage.storage().reference(forURL: "gs://fir-chat-80ed9.appspot.com")

    private lazy var userIsTypingRef: DatabaseReference = self.channelRef.child("typingIndicator").child(self.senderId)
    private lazy var usersTypingQuery: DatabaseQuery = self.channelRef.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
    private var newMessageRefHandle: DatabaseHandle?
    private var updatedMessageRefHandle: DatabaseHandle?
    
    private var messages: [JSQMessage] = []
    private var photoMessageMap = [String: JSQPhotoMediaItem]()
    private var locationMessageItems = JSQLocationMediaItem()
    private var localTyping = false
    
    var shareLocation : CLLocationCoordinate2D!
    var selectedIndex : Int = 0
    let defaults = UserDefaults.standard
    var resolveView = UIView()
    var flag : Bool?
    
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }
    
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = false
        self.channelRef = Database.database().reference().child("chaneels/9725992972/")
        self.senderId = Auth.auth().currentUser!.uid
        self.senderDisplayName = "Vishal"
        
        observeMessages()
       
        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeTyping()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = true
    }
    
    deinit {
        if let refHandle = newMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
        if let refHandle = updatedMessageRefHandle {
            messageRef.removeObserver(withHandle: refHandle)
        }
    }
    
    private func observeTyping() {
        //    if(channelRef?.child("typingIndicator") != nil) {
        if senderId == nil{
            
        }
        else{
            print(senderId)
            let typingIndicatorRef = channelRef.child("typingIndicator")
            userIsTypingRef = (typingIndicatorRef.child(senderId))
            userIsTypingRef.onDisconnectRemoveValue()
            usersTypingQuery = (typingIndicatorRef.queryOrderedByValue().queryEqual(toValue: true))
            
            usersTypingQuery.observe(.value) { (data: DataSnapshot) in
                // You're the only typing, don't show the indicator
                if data.childrenCount == 1 && self.isTyping {
                    return
                }
                // Are there others typing?
                self.showTypingIndicator = data.childrenCount > 0
                self.scrollToBottom(animated: true)
            }
        }
        //    }
    }
    
    // MARK: Firebase related methods
    private func observeMessages() {
        messageRef = channelRef.child("messages")
        let messageQuery = messageRef.queryLimited(toLast:10)
    
        // messages being written to the Firebase DB
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.count > 0 {
                self.addMessage(withId: id, name: name, text: text)
                self.finishReceivingMessage()
            } else if let id = messageData["senderId"] as String!, let photoURL = messageData["photoURL"] as String! {
                if let mediaItem = JSQPhotoMediaItem(maskAsOutgoing: id == self.senderId) {
                    self.addPhotoMessage(withId: id, key: snapshot.key, mediaItem: mediaItem)
                    
                    if photoURL.hasPrefix("gs://") {
                        self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)
                    }
                }
            }
            else if let id = messageData["senderId"], let latitude = messageData["latitude"], let longitude = messageData["longitude"]{
                
                if let mediaItem = JSQLocationMediaItem(maskAsOutgoing: id == self.senderId){
                    let lat: Double = Double(latitude)!
                    let lon: Double = Double(longitude)!
                    let location: CLLocation = CLLocation(latitude: lat, longitude: lon)
                    self.addLocationMediaMessage(withId: id, key: snapshot.key, mediaItem: mediaItem, location: location)
                    self.fetchLocationDataAtURL(latitude: lat, longitude: lon, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)
                }
            }
            else {
                print("Error! Could not decode message data")
            }
        })
        
        updatedMessageRefHandle = messageRef.observe(.childChanged, with: { (snapshot) in
            let key = snapshot.key
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let photoURL = messageData["photoURL"] as String! {
                // The photo has been updated.
                if let mediaItem = self.photoMessageMap[key] {
                    self.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: key)
                }
            }
        })
    }
    
    private func fetchImageDataAtURL(_ photoURL: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        let storageRef = Storage.storage().reference(forURL: photoURL)
        storageRef.getData(maxSize: INT64_MAX) { (data, error) in
            if let error = error {
                print("Error downloading image data: \(error)")
                return
            }
            storageRef.getMetadata(completion: { (metadata, metadataErr) in
                if let error = metadataErr {
                    print("Error downloading metadata: \(error)")
                    return
                }

                if (metadata?.contentType == "image/gif") {
                    mediaItem.image = UIImage(data: data!)
                } else {
                    mediaItem.image = UIImage.init(data: data!)
                }
                self.collectionView.reloadData()
                guard key != nil else {
                    return
                }
                self.photoMessageMap.removeValue(forKey: key!)
            })
        }
    }
    
    private func fetchLocationDataAtURL(latitude: Double , longitude: Double ,forMediaItem mediaItem: JSQLocationMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?){
        
        var storageRef = Storage.storage().reference(withPath: "\(latitude)")
        storageRef = Storage.storage().reference(withPath: "\(longitude)")
        storageRef.getMetadata { (metadata, metadataErr) in
            if (metadata?.contentType == "latitude"){
                mediaItem.location = CLLocation(latitude: latitude, longitude: longitude)
            }
        }
        storageRef.getMetadata { (metadata, metadataErr) in
            if (metadata?.contentType == "latitude"){
                mediaItem.location = CLLocation(latitude: latitude, longitude: longitude)
            }
        }
    }
    
    override func didPressAccessoryButton(_ sender: UIButton) {
        self.inputToolbar.contentView.textView.resignFirstResponder()
        // 1
        let sheet = UIAlertController(title: nil, message: "Choose Option", preferredStyle: .actionSheet)
        // 2
        let cameraImage = UIAlertAction(title: "capture image", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.cameraImageActionSheet()
        })
        let photoLibraryImage = UIAlertAction(title: "pick from photo galary", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.photoLibraryImageActionSheet()
        })
        let Location = UIAlertAction(title: "share location", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.locationActionSheet()
        })
        let Cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
        })
        // 4
        sheet.addAction(cameraImage)
        sheet.addAction(photoLibraryImage)
        sheet.addAction(Location)
        sheet.addAction(Cancel)
        // 5
        self.present(sheet, animated: true, completion: nil)
    }
    
    //---------------------------------------------------------------------------------------------------------------------------------------
    // MARK: - Image ActionSheet
    func cameraImageActionSheet(){
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            picker.sourceType = UIImagePickerControllerSourceType.camera
        }
        else {
//            Utility.showAlert(self.title, message: "Camera not available on your device", viewController: self)
        }
        present(picker, animated: true, completion:nil)
    }
    func photoLibraryImageActionSheet(){
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary)) {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        }
        present(picker, animated: true, completion:nil)
    }
    
    // MARK: - Location ActionSheet
    func locationActionSheet(){
        let config = GMSPlacePickerConfig(viewport: nil)
        let placePicker = GMSPlacePicker(config: config)
        placePicker.pickPlace { (place, error) in
            if let error = error {
                print("Pick Place error: \(error.localizedDescription)")
                return
            }
            guard let place = place else {
                print("No place selected")
                return
            }
            self.shareLocation = place.coordinate
            _ = self.buildLocationItem()
        }
    }
    
    //---------------------------------------------------------------------------------------------------------------------------------------

    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }
    
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        // 1
        let itemRef = messageRef.childByAutoId()
        // 2
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
            "timestamp":"\(Date().timeIntervalSince1970 * 1000)"
            ]
        // 3
        itemRef.setValue(messageItem)
        // 4
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        // 5
        self.finishSendingMessage()
        self.isTyping = false
    }
    
    func sendPhotoMessage() -> String? {
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "photoURL":imageURLNotSetKey,
            "senderId":senderId!,
            "timestamp":"\(Date().timeIntervalSince1970 * 1000)"
            ]
        
        itemRef.setValue(messageItem)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        finishSendingMessage()
        return itemRef.key
    }
    
    func setImageURL(_ url: String, forPhotoMessageWithKey key: String) {
        let itemRef = messageRef.child(key)
        itemRef.updateChildValues(["photoURL":url])
    }
    
    //---------------------------------------------------------------------------------------------------------------------------------------
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    private func addPhotoMessage(withId id: String, key: String, mediaItem: JSQPhotoMediaItem) {
        if let message = JSQMessage(senderId: id, displayName: "", media: mediaItem) {
            messages.append(message)
            
            if (mediaItem.image == nil) {
                photoMessageMap[key] = mediaItem
            }
            collectionView.reloadData()
        }
    }
    
    private func addLocationMediaMessage (withId id: String, key: String, mediaItem: JSQLocationMediaItem, location: CLLocation){
        
        let locations = location;
        mediaItem.setLocation(locations) {
            self.collectionView.reloadData()
        }
        
        let locationMessage: JSQMessage = JSQMessage(senderId: id, displayName: "", media: mediaItem)
        self.messages.append(locationMessage);
        self.finishSendingMessage(animated: true)
    }
    
    //---------------------------------------------------------------------------------------------------------------------------------------
    
    // MARK: Location Send Function
    func buildLocationItem() -> JSQLocationMediaItem {
        let location = CLLocation(latitude: self.shareLocation.latitude, longitude: self.shareLocation.longitude)
        let locationItem = JSQLocationMediaItem()
        locationItem.setLocation(location) {
            let itemRef = self.messageRef.childByAutoId()
            self.locationSetKey = "\(location)"
            let locationItem = [
                "location": self.locationSetKey,
                "senderId": self.senderId!,
                "latitude" : "\(self.shareLocation.latitude)",
                "longitude": "\(self.shareLocation.longitude)",
                "timestamp":"\(Date().timeIntervalSince1970 * 1000)"
                ] as [String : Any]
            
            itemRef.setValue(locationItem)
            JSQSystemSoundPlayer.jsq_playMessageSentSound()
            self.finishSendingMessage()
        }
        return locationItem
    }
        
    // MARK: UITextViewDelegate methods
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
        isTyping = textView.text != ""
    }
    
    // MARK: Collection view data source (and related) methods
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item] // 1
        if message.senderId == senderId { // 2
            return outgoingBubbleImageView
        } else { // 3
            return incomingBubbleImageView
        }
    }
        
        // MARK: - Message Tapped Call Get Image
//        func getImage(indexPath: IndexPath) -> UIImage? {
//            let message = self.messages[indexPath.row]
//            if message.isMediaMessage == true {
//                let mediaItem = message.media
//                if mediaItem is JSQPhotoMediaItem {
//                    let photoItem = mediaItem as! JSQPhotoMediaItem
//                    if let test: UIImage = photoItem.image {
//                        let image = test
//                        return image
//                    }
//                }
//            }
//            return nil
//        }
        
        // MARK: - Message Tapped Call Get Location
        func getLocation(indexPath: IndexPath) -> CLLocationCoordinate2D? {
            let message = self.messages[indexPath.row]
            if message.isMediaMessage == true {
                let mediaItem = message.media
                if mediaItem is JSQLocationMediaItem {
                    let locationItem = mediaItem as! JSQLocationMediaItem
                    if let test: CLLocationCoordinate2D = locationItem.coordinate {
                        let location = test
                        return location
                    }
                }
            }
            return nil
        }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        if message.senderId == senderId { // 1
            cell.textView?.textColor = UIColor.white // 2
        } else {
            cell.textView?.textColor = UIColor.black // 3
        }
        cell.avatarImageView.image = UIImage(named: "avatar-empty.png")
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
//        if let message = fetchedResultController.objectAtIndexPath(indexPath) as? Message {
//            return JSQMessagesAvatarImageFactory.avatarImageForUser(message.sender)
//        } else {
//            return nil
//        }
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return 15
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
//        if let chatImage = self.getImage(indexPath: indexPath) {
//            let vc = self.storyboard?.instantiateViewController(withIdentifier: "ImageViewController") as! ImageViewController
//            vc.image = chatImage
//            self.navigationController?.pushViewController(vc, animated: true)
//        }
        if let coordinateLocation = self.getLocation(indexPath: indexPath){

            let coordinate:CLLocationCoordinate2D = coordinateLocation
            let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
            let mapItem:MKMapItem = MKMapItem(placemark: placemark)
            mapItem.openInMaps(launchOptions: nil)
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView?, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString? {
        let message = messages[indexPath.item]
        switch message.senderId {
        case senderId:
            return nil
        default:
            guard let senderDisplayName = message.senderDisplayName else {
                assertionFailure()
                return nil
            }
            return NSAttributedString(string: senderDisplayName)
        }
    }
}

// MARK: Image Picker Delegate
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage

        if let key = sendPhotoMessage() {
//            let data = UIImagePNGRepresentation(image)!
            let data = UIImageJPEGRepresentation(image, 0.1)!
            let fileManager = FileManager.default;
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("file.png")
            do {
                if(fileManager.fileExists(atPath: url.path)) {
                    try fileManager.removeItem(at: url)
                }
                try data.write(to: url)
            }
            catch let error {
                print(error)
            }
            let path = "\(Auth.auth().currentUser!.uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000))/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).png"
            storageRef.child(path).putFile(from: url, metadata: nil, completion: { (metadata, error) in
                if let error = error {
                    print("Error uploading photo: \(error.localizedDescription)")
                    return
                }
                // 7
                self.setImageURL(self.storageRef.child((metadata!.path)!).description, forPhotoMessageWithKey: key)
            })
        }
        picker.dismiss(animated: true, completion:nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion:nil)
    }
}

