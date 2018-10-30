//
//  ChatViewController1.swift
//  FireBaseChat
//
//  Created by vishal on 13/12/17.
//  Copyright © 2017 vishal. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import FirebaseCore
import FirebaseStorage
import FirebaseDatabase
class ChatViewController1: JSQMessagesViewController , UIImagePickerControllerDelegate , UINavigationControllerDelegate{
    var messages = [JSQMessage]()
    
    /// Lazy computed property for painting outgoing messages blue
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()
    
    /// Lazy computed property for painting incoming messages gray
    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()
    
    var channelRef: DatabaseReference = Database.database().reference()
    private lazy var userIsTypingRef: DatabaseReference = self.channelRef.child("typingIndicator").child(self.senderId)
    private lazy var usersTypingQuery: DatabaseQuery = self.channelRef.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
     private var localTyping = false
    
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    var userID:String = ""
    var userName:String = "Vishal"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        senderId = userID
        senderDisplayName = userName

        // Show the display name dialog
            showDisplayNameDialog()
//        }
        
        // Set the navigation bar title
        title = "Chat: \(senderDisplayName!)"
        
        // Remove the message bubble avatars, and the attachment button
        inputToolbar.contentView.leftBarButtonItem = nil
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        // Prepare the Firebase query: all latest chat data limited to 10 items
        let query = Constants.refs.databaseChats.queryLimited(toLast: 10)
        
        // Observe the query for changes, and if a child is added, call the snapshot closure
        _ = query.observe(.childAdded, with: { [weak self] snapshot in
            
            // Get all the data from the snapshot
            if  let data        = snapshot.value as? [String: String],
                let id          = data["sender_id"],
                let name        = data["name"],
                let text        = data["text"],
                !text.isEmpty   // <-- check if the text length > 0
            {
                // Create a new JSQMessage object with the ID, display name and text
                if let message = JSQMessage(senderId: id, displayName: name, text: text)
                {
                    // Append to the local messages array
                    self?.messages.append(message)
                    
                    // Tell JSQMVC that we're done adding this message and that it should reload the view
                    self?.finishReceivingMessage()
                }
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        observeTyping()
        self.navigationController?.isNavigationBarHidden = false
    }
    
    @IBAction func accessoryButtonClick(_ sender: UIBarButtonItem) {
        self.imageTapClicked()
    }
    

    @objc func showDisplayNameDialog()
    {
        self.senderDisplayName = self.userName
                // Update the title
        self.title = "Chat: \(self.senderDisplayName!)"
        
        
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData!
    {
        // Return a specific message by index path
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        // Return the number of messages
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource!
    {
        // Return the right image bubble (see top): outgoing/blue for messages from the current user, and incoming/gray for other's messages
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource!
    {
        // No avatar!
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString!
    {
        // Return an attributed string with the name of the user who's text bubble is shown, displayed on top of the bubble, or return `nil` for the current user
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat
    {
        // Return the height of the bubble top label
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    private func observeTyping() {
        //    if(channelRef?.child("typingIndicator") != nil) {
        if senderId == nil{
            
        }
        else{
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
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!)
    {
        // Get a reference for a new object on the `databaseChats` reference
        let ref = Constants.refs.databaseChats.childByAutoId()
        
        // Create the message data, as a dictionary
        let message = ["sender_id": senderId, "name": senderDisplayName, "text": text]
        
        // Save the data on the new reference
        ref.setValue(message)
        
        // Tell JSQMVC we're done here
        // Note: the UI and bubbles don't update until the newly sent message is returned via the .observe(.childAdded,with:) closure. Neat!
        finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        self.inputToolbar.contentView.textView.resignFirstResponder()
        self.imageTapClicked()
    }

    //MARK:- ImagePicker Controller
    @objc func imageTapClicked(){
        imageActionSheet()
    }
    
    func imageActionSheet() {
        let actionSheet = UIAlertController(title: "Choose Option", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: UIAlertActionStyle.default, handler: { (alert:UIAlertAction!) -> Void in
            if(UIImagePickerController.isSourceTypeAvailable(.camera)) {
                self.camera()
            }
            else {
                print("Camera not available on your device")
            }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Gallery", style: UIAlertActionStyle.default, handler: { (alert:UIAlertAction!) -> Void in
            self.photoLibrary()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Video", style: UIAlertActionStyle.default, handler: { (alert:UIAlertAction!) -> Void in
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Locaion", style: UIAlertActionStyle.default, handler: { (alert:UIAlertAction!) -> Void in
            self.photoLibrary()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    func camera() {
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self
        myPickerController.sourceType = UIImagePickerControllerSourceType.camera
        self.present(myPickerController, animated: true, completion: nil)
    }
    
    func photoLibrary() {
        let myPickerController = UIImagePickerController()
        myPickerController.delegate = self
        myPickerController.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(myPickerController, animated: true, completion: nil)
    }
    
    func sendLocation(){
        
    }
    
    func sendVideo(){
        
    }
    
    // MARK: - ImagePicker Delegate Method
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
//            self.img_ProfileImageView.image = pickedImage
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
