//
//  BrowseTableViewController.swift
//  MobileTeacher
//
//  Created by Pavly Habashy on 9/7/19.
//  Copyright © 2019 Pavly Habashy. All rights reserved.
//

import UIKit
import FirebaseFirestore
import MessageUI
import SafariServices
import AVKit


let db = Firestore.firestore()
var downloadTask: URLSessionDownloadTask?

class BrowseTVC: UITableViewController {
    
    var videos = [Video]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsSelection = false
        self.readDatabase()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return videos.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! VideoTableViewCell
        cell.delegate = self
        cell.setVideo(video: videos[indexPath.row])
        return cell
    }

    
    // Read from the database
    fileprivate func readDatabase() {
        let settings = db.settings
        settings.areTimestampsInSnapshotsEnabled = true
        db.settings = settings
        
        db.collection("videos").getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
//                print(querySnapshot!.documents.count)
                for document in querySnapshot!.documents {
                    var video = Video()
                    
                    // For some reason, the lengths stored in the database are either strings or numbers.
                    // The following block takes care of that.
                    var length: Int
                    if let lengthStr = document.get("length") as? String {
                        length = Int(lengthStr)!
                    } else if let lengthInt = document.get("length") as? Int {
                        length = lengthInt
                    } else {
                        length = 0
                        print("Error")
                    }
                    
                    let (h,m,s) = self.secondsToHoursMinutesSeconds(seconds: length)
                    video.hours = h
                    video.minutes = m
                    video.seconds = s
                    
                    video.title = document.get("title") as! String
                    video.description = document.get("description") as! String
                    
                    // Add period to description
                    if video.description.suffix(1) == " " {
                        video.description = String(video.description.dropLast())
                        video.description = video.description + "."
                    }
                    else if video.description.suffix(1) == "." {
                        // Do nothing
                    }
                    else {
                        video.description = video.description + "."
                    }
                    
                    video.url = URL(string: (document.get("url") as! String))!
                    
                    let string = video.url.absoluteString
                    if string.contains("id=") {
                        
                        let array = string.components(separatedBy: "id=")
//                        print(array[1])
                        
                        video.downloadURL = URL(string: "https://drive.google.com/uc?export=download&id=\(array[1])")
                        
                    } else if string.contains("/file/d") {
                        let array = string.components(separatedBy: "/")
//                        print(array[5])
                        video.downloadURL = URL(string: "https://drive.google.com/uc?export=download&id=\(array[5])")
                    } else {
                        print("nope")
                    }
                    
                    // Get tags
                    var str = document.get("tags") as! String
                    str = str.capitalizingFirstLetter()
                    video.tags = str.components(separatedBy: ", ")
                    
                    self.videos.append(video)
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // Converts seconds into hours, minutes, and seconds
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

extension UITableViewController: VideoCellDelegate, SFSafariViewControllerDelegate, MFMessageComposeViewControllerDelegate, URLSessionDownloadDelegate {
    
    func didTapPlayButton(url: URL) {
        
        let newUrl = url.absoluteString.replacingOccurrences(of: "https://", with: "googledrive://")
        print(newUrl)
        let toUrl = URL(string: newUrl) ?? nil
        if UIApplication.shared.canOpenURL(NSURL(string: newUrl)! as URL) {
            UIApplication.shared.openURL(NSURL(string: newUrl)! as URL)
        } else {
            // Open the URL in Safari View Controller. You can the following
            let safariVC = SFSafariViewController(url: url)
            present(safariVC, animated: true, completion: nil)
            safariVC.delegate = self
        }
    }
    
    func didTapShareButton(url: URL) {
        
        // Compose new message with URL
//        if (MFMessageComposeViewController.canSendText()) {
//            let controller = MFMessageComposeViewController()
//            controller.body = "\(url)"
//            controller.recipients = []
//            controller.messageComposeDelegate = self
//            self.present(controller, animated: true, completion: nil)
//        }
        
        // Bring up Share Sheet
        let items = [url]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(ac, animated: true)
        
    }
    
    // Tapping the download button starts downloading the video.
    // Once it's done, an AV Player will pop up asynchronously.
    // Currently does not work.
    func didTapDownloadButton(url: URL) {
        
        print("Attempting to download file")
        
        // Cancel previous task
        downloadTask?.cancel()
        
        // Initialize download
        let operationQueue = OperationQueue()
        let configuration = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)

        downloadTask = urlSession.downloadTask(with: URL(string: "https://drive.google.com/uc?export=download&id=1jlgGUrFWtDsGu8DQW5QiZGsm7v6rykB0")!)
                downloadTask?.resume()
        
        // Change the download button of first cell to "Downloaded" with a checkmark icon.
        // Commented until we figure out downloads.
//        let indexPath = IndexPath(row: 0, section: 0)
//        let cell = tableView.cellForRow(at: indexPath) as! VideoTableViewCell
//        cell.downloadButtonOutlet.setTitle("Downloaded", for: .normal)
//        if #available(iOS 13.0, *) {
//            cell.downloadButtonOutlet.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
//        } else {
//            // Fallback on earlier versions
//        }
//
//        cell.downloadButtonOutlet.isEnabled = false
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("finsished downloading file")
        print(location)
        
        DispatchQueue.main.async {
            let player = AVPlayer(url: location)  // video path coming from above function

            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        }
        
        
    }
    
    // Handles dismissing the Messages controller
    public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // Handles dismissing the Safari controller
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
