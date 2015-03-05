// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

class ViewController: UIViewController, GCKDeviceScannerListener, GCKDeviceManagerDelegate,
    GCKMediaControlChannelDelegate, UIActionSheetDelegate {
  private let kCancelTitle = "Cancel"
  private let kDisconnectTitle = "Disconnect"
  // Publicly available receiver to demonstrate sending messages - replace this with your
  // own custom app ID.
  private let kReceiverAppID = "794B7BBF"
  private lazy var btnImage:UIImage = {
    return UIImage(named: "icon-cast-identified.png")!
  }()
  private lazy var btnImageselected:UIImage = {
    return UIImage(named: "icon-cast-connected.png")!
  }()
  private lazy var chromecastButton:UIButton = {
    //Create cast button
    var button:UIButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    button.addTarget(self, action: "chooseDevice:", forControlEvents: UIControlEvents.TouchUpInside)
    button.frame = CGRectMake(0, 0, self.btnImage.size.width, self.btnImage.size.height)
    button.hidden = true;
    return button;
  }()
  private lazy var textChannel:TextChannel = {
    return TextChannel(namespace: "urn:x-cast:com.google.cast.sample.helloworld")
  }()
  private var deviceScanner:GCKDeviceScanner = GCKDeviceScanner()
  private var deviceManager:GCKDeviceManager?
  private var mediaInformation:GCKMediaInformation?
  private var selectedDevice:GCKDevice?

  @IBOutlet weak var messageField: UITextField?

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView:self.chromecastButton)

    // Initialize device scanner
    self.deviceScanner.addListener(self)
    self.deviceScanner.startScan()
  }

  func updateButtonStates() {
    if (deviceScanner.devices.count == 0) {
      //Hide the cast button
      chromecastButton.hidden = true;
    } else {
      //Show cast button
      chromecastButton.hidden = false;

      if isConnected() {
        chromecastButton.setImage(btnImageselected, forState: UIControlState.Normal);
      } else {
        chromecastButton.setImage(btnImage, forState: UIControlState.Normal);
      }
    }
  }

  func isConnected() -> Bool {
    if let manager = deviceManager {
      return manager.isConnected
    } else {
      return false
    }
  }

  func connectToDevice() {
    if (selectedDevice == nil) {
      return
    }
    let identifier = NSBundle.mainBundle().infoDictionary?["CFBundleIdentifier"] as String
    deviceManager = GCKDeviceManager(device: selectedDevice, clientPackageName: identifier)
    deviceManager!.delegate = self
    deviceManager!.connect()
  }

  func deviceDisconnected() {
    selectedDevice = nil
    deviceManager = nil
  }

  func showError(error: NSError) {
    var alert = UIAlertController(title: "Error", message: error.description, preferredStyle: UIAlertControllerStyle.Alert);
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
    self.presentViewController(alert, animated: true, completion: nil)
  }

  func chooseDevice(sender:AnyObject) {
    if (selectedDevice == nil) {
      var sheet : UIActionSheet = UIActionSheet(title: "Connect to Device",
        delegate: self,
        cancelButtonTitle: nil,
        destructiveButtonTitle: nil)

      for device in deviceScanner.devices  {
        sheet.addButtonWithTitle(device.friendlyName)
      }

      // Add the cancel button at the end so that indexes of the titles map to the array index.
      sheet.addButtonWithTitle(kCancelTitle);
      sheet.cancelButtonIndex = sheet.numberOfButtons - 1;

      sheet.showInView(chromecastButton)

    } else {
      let friendlyName = "Casting to \(selectedDevice!.friendlyName)";

      var sheet : UIActionSheet = UIActionSheet(title: friendlyName,
          delegate: self, cancelButtonTitle: nil,
          destructiveButtonTitle: nil);
      var buttonIndex = 0;

      if let info = mediaInformation {
        sheet.addButtonWithTitle(info.metadata.objectForKey(kGCKMetadataKeyTitle) as String);
        buttonIndex++;
      }

      // Offer disconnect option.
      sheet.addButtonWithTitle(kDisconnectTitle);
      sheet.addButtonWithTitle(kCancelTitle);
      sheet.destructiveButtonIndex = buttonIndex++;
      sheet.cancelButtonIndex = buttonIndex;

      sheet.showInView(chromecastButton);
    }
  }


  @IBAction func sendText(sender: AnyObject?) {
    if let messageField = self.messageField {
      println("Sending text \(messageField.text)")
      if (deviceManager == nil || !deviceManager!.isConnected) {
        var alert = UIAlertController(title: "Not Connected",
          message: "Please connect to a Cast device.",
          preferredStyle: UIAlertControllerStyle.Alert);
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
        return;
      }
      self.textChannel.sendTextMessage(messageField.text)
    }
  }

  // MARK: GCKDeviceScannerListener

  func deviceDidComeOnline(device: GCKDevice!) {
    println("Device found: \(device.friendlyName)");
    updateButtonStates();
  }

  func deviceDidGoOffline(device: GCKDevice!) {
    println("Device went away: \(device.friendlyName)");
    updateButtonStates();
  }


  // MARK: UIActionSheetDelegate
  func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
      return;
    } else if (selectedDevice == nil) {
      if (buttonIndex < deviceScanner.devices.count) {
        selectedDevice = deviceScanner.devices[buttonIndex] as? GCKDevice;
        println("Selected device: \(selectedDevice!.friendlyName)");
        connectToDevice();
      }
    } else if (actionSheet.buttonTitleAtIndex(buttonIndex) == kDisconnectTitle) {
      // Disconnect button.
      deviceManager!.leaveApplication();
      deviceManager!.disconnect();
      deviceDisconnected();
      updateButtonStates();
    }
  }


  // MARK: GCKDeviceManagerDelegate
  func deviceManagerDidConnect(deviceManager: GCKDeviceManager!) {
    println("Connected.");

    updateButtonStates();
    deviceManager.launchApplication(kReceiverAppID);
  }

  func deviceManager(deviceManager: GCKDeviceManager!,
    didConnectToCastApplication
    applicationMetadata: GCKApplicationMetadata!,
    sessionID: String!,
    launchedApplication: Bool) {
      println("Application has launched.");
      deviceManager.addChannel(self.textChannel)
  }

  func deviceManager(deviceManager: GCKDeviceManager!,
    didFailToConnectToApplicationWithError error: NSError!) {
      println("Received notification that device failed to connect to application.");

      showError(error);
      deviceDisconnected();
      updateButtonStates();
  }

  func deviceManager(deviceManager: GCKDeviceManager!,
    didFailToConnectWithError error: NSError!) {
      println("Received notification that device failed to connect.");

      showError(error);
      deviceDisconnected();
      updateButtonStates();
  }

  func deviceManager(deviceManager: GCKDeviceManager!,
    didDisconnectWithError error: NSError!) {
      println("Received notification that device disconnected.");

      if (error != nil) {
        showError(error)
      }

      deviceDisconnected();
      updateButtonStates();
  }

}