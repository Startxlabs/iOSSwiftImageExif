import UIKit
import BSImagePicker
import Photos

// MARK:- Save image with latitude, longitude and altitude in exif

func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    
    let image = info[UIImagePickerControllerOriginalImage] as! UIImage
    
    PHPhotoLibrary.shared().performChanges({() -> Void in
        
        let newImage = image.resizedImage(withMaxSize: 900)
        
        let imageMetadata = info[UIImagePickerControllerMediaMetadata] as? [AnyHashable: Any]
        
        var metadataAsMutable = imageMetadata
        
        var GPSDictionary = (metadataAsMutable?[(kCGImagePropertyGPSDictionary as String)]) as? [AnyHashable: Any]
        
        if GPSDictionary == nil {
            GPSDictionary = [AnyHashable: Any]()
        }
        
        self.imageCoordinate.latitude = latitude
        self.imageCoordinate.longitude = longitude
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        incidentDate = "\(Date().isoDate())"
        incidentTime = "\(Date().isoTime())"
        
        self.geoCoordinates.append(coordinate)
        
        GPSDictionary?[(kCGImagePropertyGPSLatitude as String)] = self.convertToPositive(latitude)
        GPSDictionary?[(kCGImagePropertyGPSLatitudeRef as String)] = self.getLatitudeRefDirection(latitude)
        GPSDictionary?[(kCGImagePropertyGPSLongitude as String)] = self.convertToPositive(longitude)
        GPSDictionary?[(kCGImagePropertyGPSLongitudeRef as String)] = self.getLongtitudeRefDirection(longitude)
        GPSDictionary?[(kCGImagePropertyGPSAltitude as String)] = altitude
        GPSDictionary?[(kCGImagePropertyGPSTimeStamp as String)] = Date().isoTime()
        GPSDictionary?[(kCGImagePropertyGPSDateStamp as String)] = Date().isoDate()
        
        metadataAsMutable?[(kCGImagePropertyGPSDictionary as String)] = GPSDictionary
        
        metadataAsMutable?[kCGImagePropertyTIFFOrientation as String] = "1"
        
        let source: CGImageSource = CGImageSourceCreateWithData(UIImageJPEGRepresentation(newImage, 1)! as NSData, nil)!
        
        let UTI: CFString = CGImageSourceGetType(source)!
        
        let newImageData = NSMutableData()
        let destination: CGImageDestination = CGImageDestinationCreateWithData((newImageData as CFMutableData), UTI, 1, nil)!
        
        CGImageDestinationAddImageFromSource(destination, source, 0, metadataAsMutable! as CFDictionary)
        
        CGImageDestinationFinalize(destination)
        
        let creationRequest = PHAssetCreationRequest.forAsset()
        
        creationRequest.addResource(with: .photo, data: newImageData as Data, options: nil)
        
        self.imageData.add(newImageData)
        
        if let imageSource = CGImageSourceCreateWithData(newImageData, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)! as NSDictionary
            print(imageProperties)
            
        }
        
        DispatchQueue.main.async {
            
            self.collectionView.delegate = self
            self.collectionView.dataSource = self
            self.collectionView.reloadData()
            
        }
        
    })
    
    imagePicker.dismiss(animated: true, completion: nil)
    
}

//MARK:- Get Image from gallery

@IBAction func galleryBtnAction(_ sender: UIButton) {
    
    let vc = BSImagePickerViewController()
    vc.maxNumberOfSelections = 10
    
    bs_presentImagePickerController(vc, animated: true,
                                    select: { (asset: PHAsset) -> Void in
                                        print("Selected: \(asset)")
    }, deselect: { (asset: PHAsset) -> Void in
        print("Deselected: \(asset)")
    }, cancel: { (assets: [PHAsset]) -> Void in
        print("Cancel: \(assets)")
    }, finish: { (assets: [PHAsset]) -> Void in
        print("Finish: \(assets)")
        
        let requestOptions = PHImageRequestOptions()
        
        requestOptions.isSynchronous = true
        requestOptions.isNetworkAccessAllowed = true
        
        for asset in assets
        {
            if (asset.mediaType == PHAssetMediaType.image)
            {
                
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: PHImageContentMode.default, options: requestOptions, resultHandler: { (pickedImage, info) in
                    
                    if let img = pickedImage as? UIImage{
                        
                        let imageManager = PHImageManager.default()
                        imageManager.requestImageData(for: asset , options: nil, resultHandler:{
                            (data, responseString, imageOriet, info) -> Void in
                            
                            let newImage = UIImage(data: data!)?.resizedImage(withMaxSize: 900)
                            
                            let imageData: NSData = data! as NSData
                            
                            if let imageSource = CGImageSourceCreateWithData(imageData, nil) {
                                let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)! as NSDictionary
                                print(imageProperties)
                                
                                var metadataAsMutable = imageProperties as? [AnyHashable: Any]
                                
                                metadataAsMutable![kCGImagePropertyTIFFOrientation as String] = "1"
                                
                                let newImageData = self.data(from: newImage!, metadata: metadataAsMutable as! [AnyHashable : Any], mimetype: "image/jpeg")
                                
                                self.imageData.add(newImageData)
                                
                                
                                if let Gps = (imageProperties as NSDictionary).value(forKey: "{GPS}")as? NSDictionary{
                                    
                                    if Gps.value(forKey: "Latitude")as? Double != 0 && Gps.value(forKey: "Longitude")as? Double != 0{
                                        
                                        if Gps.value(forKey: "DateStamp") != nil{
                                            
                                            incidentDate = "\(Gps.value(forKey: "DateStamp")as! String)"
                                            
                                        }
                                        
                                        if Gps.value(forKey: "TimeStamp") != nil{
                                            
                                            incidentTime = "\(Gps.value(forKey: "TimeStamp")as! String)"
                                            
                                        }
                                        
                                        self.imageCoordinate.latitude = self.getLatitudeValue(Gps.value(forKey: "LatitudeRef")as! String, (Gps.value(forKey: "Latitude")as? Double)!)
                                        self.imageCoordinate.longitude = self.getLongitudeValue(Gps.value(forKey: "LongitudeRef")as! String, (Gps.value(forKey: "Longitude")as? Double)!)
                                        
                                        let coordinate = CLLocationCoordinate2D(latitude: self.getLatitudeValue(Gps.value(forKey: "LatitudeRef")as! String, (Gps.value(forKey: "Latitude")as? Double)!), longitude: self.getLongitudeValue(Gps.value(forKey: "LongitudeRef")as! String, (Gps.value(forKey: "Longitude")as? Double)!))
                                        
                                        self.geoCoordinates.append(coordinate)
                                        
                                    }
                                    
                                }
                                
                                DispatchQueue.main.async {
                                    
                                    self.collectionView.delegate = self
                                    self.collectionView.dataSource = self
                                    self.collectionView.reloadData()
                                    
                                }
                                
                            }
                            
                        })
                        
                    }else{
                        
                        self.showAlert(withMessage: "Image is not appropriate")
                        
                    }
                    
                })
                
            }
        }
        
    }, completion: nil)
    
}

//MARK:- Usefull Methods

func getLatitudeRefDirection(_ lat : Double)-> String{
    
    if lat > 0{
        return "N"
    }else{
        return "S"
    }
    
}

func getLatitudeValue(_ latitudeRef : String,_ latitude : Double)-> Double{
    
    if latitudeRef == "S"{
        
        if latitude > 0{
            return (latitude * -1)
        }
        return (latitude)
        
    }else{
        return latitude
    }
    
}

func getLongtitudeRefDirection(_ long: Double)-> String{
    
    if long > 0{
        return "E"
    }else{
        return "W"
    }
    
}

func getLongitudeValue(_ longitudeRef : String,_ longitude : Double)-> Double{
    
    if longitudeRef == "W"{
        
        if longitude > 0{
            return (longitude * -1)
        }
        return (longitude)
        
    }else{
        return longitude
    }
    
}

func convertToPositive(_ val : Double)-> Double{
    
    if val > 0{
        return val
    }else{
        return (val * -1)
    }
    
}

func data(from image: UIImage, metadata: [AnyHashable: Any], mimetype: String) -> Data {
    
    let source: CGImageSource = CGImageSourceCreateWithData(UIImageJPEGRepresentation(image, 1)! as NSData, nil)!
    
    let UTI: CFString = CGImageSourceGetType(source)!
    
    var imageData =  NSMutableData()
    
    let imageDestination: CGImageDestination = CGImageDestinationCreateWithData((imageData as CFMutableData), UTI, 1, nil)!
    if imageDestination == nil {
        print("Failed to create image destination")
        
    }
    else {
        CGImageDestinationAddImage(imageDestination, image.cgImage!, (metadata as? CFDictionary))
        if CGImageDestinationFinalize(imageDestination) == false {
            print("Failed to finalise")
            
        }
    }
    return imageData as Data
}
