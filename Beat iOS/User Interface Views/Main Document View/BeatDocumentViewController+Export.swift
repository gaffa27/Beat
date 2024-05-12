//
//  BeatDocumentViewController+Export.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 12.5.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import Foundation
import BeatFileExport

extension BeatDocumentViewController {
	
	@objc public func exportFile(type:String) {
		if let url = BeatFileExportManager.shared.export(delegate: self, format: type) {
			let shareController = BeatShareSheetController(items: [url], excludedTypes: [.assignToContact, .addToReadingList, .postToFacebook, .postToVimeo, .postToTwitter, .postToWeibo, .postToFlickr, .postToTencentWeibo])
			
			self.present(shareController, animated: true) {
			}
		}
	}	
}
