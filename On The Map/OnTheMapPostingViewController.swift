//
//  OnTheMapPostingViewController.swift
//  On The Map
//
//  Created by Joseph Vallillo on 3/8/16.
//  Copyright © 2016 Joseph Vallillo. All rights reserved.
//

import UIKit
import MapKit

// MARK: OTMPostingViewController: UIViewController
class OnTheMapPostingViewController: UIViewController {
    
    //MARK: PostingState
    private enum PostingState { case MapString, MediaURL }
    
    //MARK: Properties
    private let otmDataSource = OnTheMapDataSource.sharedDataSource()
    private let parseClient = ParseClient.sharedClient()
    private var placemark: CLPlacemark? = nil
    var objectID: String?
    
    //MARK: Outlets
    @IBOutlet weak var postingMapView: MKMapView!
    @IBOutlet weak var studyingLabel: UILabel!
    @IBOutlet weak var topSectionView: UIView!
    @IBOutlet weak var middleSectionView: UIView!
    @IBOutlet weak var bottomSectionView: UIView!
    @IBOutlet weak var mapStringTextField: UITextField!
    @IBOutlet weak var mediaURLTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var findButton: BorderedButton!
    @IBOutlet weak var submitButton: BorderedButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    //MARK: View Controller Life Cycle
    
    //MARK: Actions
    @IBAction func canel(sender: UIButton) {
        dismissController()
    }
    
    @IBAction func findOnTheMap(sender: UIButton) {
        //check for empty string
        if mapStringTextField.text!.isEmpty {
            displayAlert(AppConstants.Errors.MapStringEmpty)
            return
        }
        //start activity indicator
        startActivity()
        //add placemark
        let delayInSeconds = 1.5
        let delay = delayInSeconds * Double(NSEC_PER_SEC)
        let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(popTime, dispatch_get_main_queue()) {
            let geocoder = CLGeocoder()
            do {
                geocoder.geocodeAddressString(self.mapStringTextField.text!, completionHandler: { (result, error) -> Void in
                    if let _ = error {
                        self.displayAlert(AppConstants.Errors.CouldNotGeocode)
                    } else if (result!.isEmpty) {
                        self.displayAlert(AppConstants.Errors.NoLocationFound)
                    } else {
                        self.placemark = result![0]
                        self.configureUI(.MediaURL)
                        self.postingMapView.showAnnotations([MKPlacemark(placemark: self.placemark!)], animated: true)
                    }
                })
            }
        }
    }
    
    @IBAction func submitStudentLocation(sender: UIButton) {
        activityIndicator.hidden = false
        activityIndicator.startAnimating()
        
        //check for empty string
        if mediaURLTextField.text!.isEmpty {
            displayAlert(AppConstants.Errors.URLEmpty)
            return
        }
        //check if student and placemark initialized
        guard let student = otmDataSource.currentStudent,
        let placemark = placemark,
            let postedLocation = placemark.location else {
                displayAlert(AppConstants.Errors.StudentAndPlacemarkEmpty)
                return
        }
        //define request handler
        let handleRequest: ((NSError?, String) -> Void) = { (error, mediaURL) in
            if let _ = error {
                self.displayAlert(AppConstants.Errors.PostStudentLocationFailed) { (alert) in
                    self.dismissController()
                }
            } else {
                self.otmDataSource.currentStudent!.mediaURL = mediaURL
                self.otmDataSource.refreshStudentLocations()
                self.dismissController()
            }
        }
        
        //init new values
        let location = Location(latitude: postedLocation.coordinate.latitude, longitude: postedLocation.coordinate.longitude, mapString: mapStringTextField.text!)
        let mediaURL = mediaURLTextField.text!
        
        if let objectID = objectID {
            parseClient.updateStudentLocationWithObjectID(objectID, mediaURL: mediaURL, studentLocation: StudentLocation(objectID: objectID, student: student, location: location)) { (success, error) in
                handleRequest(error, mediaURL)
            }
        } else {
            parseClient.postStudentLocation(mediaURL, studentLocation: StudentLocation(objectID: "", student: student, location: location)) { (success, error) in
                handleRequest(error, mediaURL)
            }
        }
    }
    
    @IBAction func userDidTapView(sender: UITapGestureRecognizer) {
        resignIfFirstResponder(mapStringTextField)
        resignIfFirstResponder(mediaURLTextField)
    }
    
    //MARK: Display Alert
    private func displayAlert(message: String, completionHandler: ((UIAlertAction) -> Void)? = nil) {
        dispatch_async(dispatch_get_main_queue()) {
            self.stopActivity()
            let alert = UIAlertController(title: "", message: message, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: AppConstants.AlertActions.Dismiss, style: .Default, handler: completionHandler))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    //MARK: Configure UI
    private func dismissController() {
        if let presentingViewController = presentingViewController {
            presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    private func setupUI() {
        studyingLabel.textColor = AppConstants.UI.OTMBlueColor
        findButton.setTitleColor(AppConstants.UI.OTMBlueColor, forState: .Normal)
        submitButton.setTitleColor(AppConstants.UI.OTMBlueColor, forState: .Normal)
        
        mapStringTextField.delegate = self
        mediaURLTextField.delegate = self
        
        activityIndicator.hidden = true
        activityIndicator.stopAnimating()
    }
    
    private func configureUI(state: PostingState, location: CLLocationCoordinate2D? = nil) {
        stopActivity()
    }
    
    //MARK: Configure UI (Activity)
    private func startActivity() {
        activityIndicator.hidden = false
        activityIndicator.startAnimating()
        setFindingUIEnabled(false)
        setFindingUIAlpha(0.5)
    }
    
    private func stopActivity() {
        activityIndicator.hidden = true
        activityIndicator.stopAnimating()
        setFindingUIEnabled(true)
        setFindingUIAlpha(1.0)
    }
    
    private func setFindingUIEnabled(enabled: Bool) {
        mapStringTextField.enabled = enabled
        findButton.enabled = enabled
        cancelButton.enabled = enabled
        studyingLabel.enabled = enabled
    }
    
    private func setFindingUIAlpha(alpha: CGFloat) {
        mapStringTextField.alpha = alpha
        findButton.alpha = alpha
        cancelButton.alpha = alpha
        studyingLabel.alpha = alpha
    }
}

//MARK: - OnTheMapPostingViewController: UITextFieldDelegate
extension OnTheMapPostingViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
