//
//  UITableView+Separated.swift
//  ReactiveAdventures
//
//  Created by Murillo Nicacio de Maraes on 6/15/15.
//  Copyright (c) 2015 TIL. All rights reserved.
//

import UIKit


protocol UITableViewLayoutDelegate {
    func numberOfRows(tableView: UITableView) -> Int
//    func heightForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> CGFloat
    func cellForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> UITableViewCell
}

protocol UITableViewSectionDelegate {
    func numberOfSections(tableView: UITableView) -> Int
    func numberOfRows(tableView: UITableView, inSection section: Int) -> Int

    func headerView(section: Int, inTableView tableView: UITableView) -> UIView?
    func footerView(section: Int, inTableView tableView: UITableView) -> UIView?

    func headerTitle(section: Int, inTableView tableView: UITableView) -> String?
    func footerTitle(section: Int, inTableView tableView: UITableView) -> String?
}

protocol UITableViewActionDelegate {
    func willDisplayCell(cell: UITableViewCell, inTableView tableView: UITableView, atIndexPath indexPath: NSIndexPath)
    func didEndDisplayingCell(cell: UITableViewCell, inTableView tableView: UITableView, atIndexPath indexPath: NSIndexPath)
    func didSelect(tableView: UITableView, atIndexPath indexPath: NSIndexPath)
}

final class DelegatedUITableViewManager: NSObject, UITableViewDataSource, UITableViewDelegate {
    let layoutDelegate: UITableViewLayoutDelegate
    let sectionDelegate: UITableViewSectionDelegate?
    let actionDelegate: UITableViewActionDelegate?

    var holdOn: DelegatedUITableViewManager!
    var hold: AnyObject!

    init(layoutDelegate: UITableViewLayoutDelegate,
        sectionDelegate: UITableViewSectionDelegate? = nil,
        actionDelegate: UITableViewActionDelegate? = nil) {
            self.layoutDelegate = layoutDelegate
            self.sectionDelegate = sectionDelegate
            self.actionDelegate = actionDelegate
            self.holdOn = nil

            super.init()

            self.holdOn = self
    }

    //MARK: Section Methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sectionDelegate?.numberOfSections(tableView) ?? 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionDelegate?.numberOfRows(tableView, inSection: section) ?? layoutDelegate.numberOfRows(tableView)
    }

    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionDelegate?.headerView(section, inTableView: tableView)
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let headerView = sectionDelegate?.headerView(section, inTableView: tableView)

        return headerView?.bounds.height ?? 0.0
    }

//    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
//        return sectionDelegate?.footerView(section, inTableView: tableView)
//    }
//
//    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return sectionDelegate?.headerTitle(section, inTableView: tableView)
//    }
//
//    func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
//        return sectionDelegate?.footerTitle(section, inTableView: tableView)
//    }

    //MARK: Layout Methods
//    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
//        return layoutDelegate.heightForIndexPath(indexPath, inTableView: tableView)
//    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return layoutDelegate.cellForIndexPath(indexPath, inTableView: tableView)
    }

    //MARK: Action Methods
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        actionDelegate?.willDisplayCell(cell, inTableView: tableView, atIndexPath: indexPath)
    }

    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        actionDelegate?.didEndDisplayingCell(cell, inTableView: tableView, atIndexPath: indexPath)
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        actionDelegate?.didSelect(tableView, atIndexPath: indexPath)
    }
}