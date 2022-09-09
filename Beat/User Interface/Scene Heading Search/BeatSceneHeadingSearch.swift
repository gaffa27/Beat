//
//  BeatSceneHeadingSearch.swift
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.9.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 This class is a mess but it works. It's also very late, so I don't care.
 
 */

import Cocoa

class BeatSceneHeadingSearch:NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSControlTextEditingDelegate
 {
	@objc var delegate:BeatEditorDelegate?
	@IBOutlet var textField:NSTextField?
	@IBOutlet var tableView:NSTableView?
	
	var results:[OutlineScene] = []
	
	override var windowNibName: String! {
		return "BeatSceneHeadingSearch"
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override init(window: NSWindow?) {
		super.init(window: window)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		textField?.delegate = self
		delegate?.parser.createOutline()
		results = delegate?.parser.outline as! [OutlineScene]
	}
	
	
	
	override func cancelOperation(_ sender: Any?) {
		// Esc pressed
		//self.closeModal()
		self.closeModal()
	}
	
	
	func controlTextDidChange(_ obj: Notification) {
		filter(textField?.stringValue ?? "")
	}

	//var backspaces:Int = 0
	override func keyUp(with event: NSEvent) {
		/*
		if textField!.stringValue.count > 0 {
			backspaces = 0
		}
		 */
		
		// Close on esc
		if event.keyCode == 53 {
			self.closeModal()
			return
		}
		// Close on backspace and empty text field {
		else if event.keyCode == 51 {
			/*
			if textField!.stringValue.count == 0 {
				backspaces += 1
				if backspaces > 1 {
					self.closeModal()
				}
			}
			 */
		}
		// Select on enter
		else if event.keyCode == 36 {
			selectScene()
		}
		
		else if event.keyCode == 126 {
			// up
			if tableView!.numberOfRows > 0 {
				var selected = tableView!.selectedRow - 1;
				if (selected <= 0) { selected = tableView!.numberOfRows - 1; }
				tableView?.selectRowIndexes([selected], byExtendingSelection: false)
				tableView?.scrollRowToVisible(tableView!.selectedRow)
				return
			}
		}
		else if event.keyCode == 125 {
			// down
			if tableView!.numberOfRows > 0 {
				var selected = tableView!.selectedRow + 1;
				if (selected >= tableView!.numberOfRows) { selected = 0; }
				tableView?.selectRowIndexes([selected], byExtendingSelection: false)
				tableView?.scrollRowToVisible(tableView!.selectedRow)
				return
			}
		}
				
		super.keyUp(with: event)
	}
	
	func closeModal() {
		self.delegate?.documentWindow.endSheet(self.window!)
	}
	
	// MARK: - Filtering and jumping to scene
	
	func selectScene() {
		if (self.tableView!.numberOfRows > 0) {
			// Get selected scene from the table (usually the first one)
			let scene = self.tableView!.dataSource!.tableView!(self.tableView!, objectValueFor: nil, row: tableView!.selectedRow) as? OutlineScene ?? nil
			
			// Scroll to selected scene and close this menu
			if (scene != nil) {
				self.delegate?.scroll(to: scene!.line)
				closeModal()
				return
			}
		}
		
		// Something went wrong or the search was empty, so just close the dialog
		closeModal()
	}
	
	func filter(_ string:String) {
		if (self.delegate == nil) { return }
		
		if (string.count == 0) {
			results = delegate!.parser.outline as! [OutlineScene]
		} else {
			results = []
		}

		let searchString = string.uppercased()
		
		for item in self.delegate!.parser.outline {
			let scene = item as! OutlineScene
			
			let sceneNumber = (scene.sceneNumber ?? "").uppercased()
			let sceneTitle = scene.string.uppercased()
						
			if sceneTitle.contains(searchString) || sceneNumber.contains(searchString) {
				results.append(scene)
			}
		}
		
		tableView?.reloadData()
		if (tableView!.numberOfRows > 0) {
			tableView?.selectRowIndexes([0], byExtendingSelection: false)
		}
	}
			
	func numberOfRows(in tableView: NSTableView) -> Int {
		return results.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if (item != nil) {
			return 0
		} else {
			return results.count
		}
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return results[row]
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let scene = results[row]
		let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SceneView"), owner: self) as! BeatSceneHeadingView
		view.textField?.stringValue = scene.stringForDisplay()
		view.sceneNumber?.stringValue = scene.sceneNumber ?? ""
		
		return view
	}
}

class BeatSceneHeadingView:NSTableCellView {
	@IBOutlet var sceneNumber:NSTextField?
}

class BeatSceneHeadingTextField:NSTextField {
	override func cancelOperation(_ sender: Any?) {
		self.window?.windowController?.cancelOperation(sender)
	}
}
